"""Capacity reservation helpers for multi-device BrowserStack tests."""

from __future__ import annotations

import asyncio
import time
from functools import partial
from typing import Any, Dict, Optional

from config.logging_config import get_logger
from utils.exceptions import SessionManagementError
from core.providers.browserstack_plan import BrowserStackPlanClient, BrowserStackPlanStatus

_shared_pending_counter = None


def set_shared_pending_counter(counter: Any) -> None:
    """Register the shared pending counter used across pytest workers."""

    global _shared_pending_counter
    _shared_pending_counter = counter


def get_shared_pending_counter() -> Any:
    """Return the shared pending counter if registered."""

    return _shared_pending_counter


def create_plan_client(env_config: Optional[Any]) -> Optional[BrowserStackPlanClient]:
    """Create a BrowserStack Plan client when credentials are available."""

    if not env_config or not getattr(env_config, "provider", None):
        return None

    provider = env_config.provider
    if provider.name.lower() != "browserstack":
        return None

    auth_cfg = provider.options.get("auth", {})
    username = env_config.resolve_template(auth_cfg.get("username", ""))
    access_key = env_config.resolve_template(auth_cfg.get("access_key", ""))
    if not username or not access_key:
        return None

    cache_ttl = int(env_config.get_provider_option("plan_cache_ttl", 10))
    return BrowserStackPlanClient(username, access_key, cache_ttl=cache_ttl)


class CapacityReserver:
    """Coordinates BrowserStack capacity reservations for SessionPool."""

    def __init__(
        self,
        *,
        plan_client: Optional[BrowserStackPlanClient],
        concurrency_limits: Optional[Dict[str, int]],
        throttle_config: Optional[Dict[str, Any]],
        shared_pending_counter: Any = None,
        logger=None,
    ) -> None:
        self._plan_client = plan_client
        self._concurrency_limits = concurrency_limits or {}
        self._throttle_config = throttle_config or {}
        self._shared_counter = (
            shared_pending_counter if shared_pending_counter is not None else get_shared_pending_counter()
        )
        self._logger = logger or get_logger("capacity_reserver")
        self._local_pending = 0

    async def reserve(self, count: int) -> None:
        if count <= 0:
            return

        cfg = self._throttle_config
        if not cfg.get("enabled", True):
            self._commit_reservation(count)
            return

        poll_interval = max(1, int(cfg.get("poll_interval", 10)))
        timeout = cfg.get("timeout", 90)
        parallel_buffer = max(0, int(cfg.get("parallel_buffer", 0)))
        queue_buffer = max(0, int(cfg.get("queue_buffer", 0)))

        deadline: Optional[float] = None
        if timeout and timeout > 0:
            deadline = time.monotonic() + float(timeout)

        attempt = 0
        while True:
            status = await self._fetch_plan_status()
            self._assert_request_feasible(
                count,
                status,
                parallel_buffer,
                queue_buffer,
            )
            if self._try_reserve(count, status, parallel_buffer, queue_buffer):
                if attempt:
                    self._logger.info(
                        "Capacity available after %d attempt(s); reserved %d device(s)",
                        attempt,
                        count,
                    )
                else:
                    self._logger.debug("Capacity available; reserved %d device(s)", count)
                return

            if deadline and time.monotonic() >= deadline:
                raise SessionManagementError(
                    "Timed out waiting for BrowserStack capacity (reason=capacity)"
                )

            self._logger.warning(
                "Capacity unavailable (attempt=%d). Retrying in %ds",
                attempt + 1,
                poll_interval,
            )
            attempt += 1
            await asyncio.sleep(poll_interval)

    async def release(self, count: int) -> None:
        if count <= 0:
            return

        if self._shared_counter:
            lock = self._shared_counter.get_lock()
            with lock:
                current = lock.get_value()
                lock.set_value(max(0, current - count))

        self._local_pending = max(0, self._local_pending - count)

    async def _fetch_plan_status(self) -> Optional[BrowserStackPlanStatus]:
        if not self._plan_client:
            return None

        loop = asyncio.get_running_loop()
        func = partial(self._plan_client.get_plan_status, force_refresh=True)
        return await loop.run_in_executor(None, func)

    def _try_reserve(
        self,
        count: int,
        status: Optional[BrowserStackPlanStatus],
        parallel_buffer: int,
        queue_buffer: int,
    ) -> bool:
        if self._shared_counter:
            lock = self._shared_counter.get_lock()
            with lock:
                shared_pending = lock.get_value()

                if not self._has_capacity(count, status, shared_pending, parallel_buffer, queue_buffer):
                    return False

                lock.set_value(shared_pending + count)
                self._local_pending += count
                return True
        else:
            shared_pending = self._local_pending
            if not self._has_capacity(count, status, shared_pending, parallel_buffer, queue_buffer):
                return False
            self._local_pending += count
            return True

    def _has_capacity(
        self,
        count: int,
        status: Optional[BrowserStackPlanStatus],
        shared_pending: int,
        parallel_buffer: int,
        queue_buffer: int,
    ) -> bool:
        max_sessions = self._concurrency_limits.get("max_sessions")

        if status is None:
            if max_sessions is None:
                return True
            available_parallel = max_sessions - shared_pending - parallel_buffer
            return available_parallel >= count

        parallel_limit = status.parallel_allowed if status.parallel_allowed > 0 else None
        if max_sessions:
            parallel_limit = min(parallel_limit, max_sessions) if parallel_limit is not None else max_sessions

        parallel_running = status.parallel_running
        effective_parallel = parallel_running + shared_pending + parallel_buffer
        available_parallel = (
            float("inf")
            if parallel_limit is None
            else max(0, parallel_limit - effective_parallel)
        )

        queue_limit = status.queued_allowed if status.queued_allowed > 0 else None
        if queue_limit is not None:
            queue_limit = max(0, queue_limit - queue_buffer)
        queue_depth = status.queued_sessions
        available_queue = (
            None
            if queue_limit is None
            else max(0, queue_limit - queue_depth)
        )

        return available_parallel >= count or (
            available_queue is not None and available_queue >= count
        )

    def _commit_reservation(self, count: int) -> None:
        if self._shared_counter:
            lock = self._shared_counter.get_lock()
            with lock:
                current = lock.get_value()
                lock.set_value(current + count)
        self._local_pending += count

    def _assert_request_feasible(
        self,
        count: int,
        status: Optional[BrowserStackPlanStatus],
        parallel_buffer: int,
        queue_buffer: int,
    ) -> None:
        max_sessions = self._concurrency_limits.get("max_sessions")
        if max_sessions and count > max_sessions:
            raise SessionManagementError(
                "Requested %d device(s) but BrowserStack plan allows only %d parallel session(s)."
                % (count, max_sessions)
            )

        if not status:
            return

        parallel_limit = status.parallel_allowed if status.parallel_allowed > 0 else None
        if max_sessions:
            parallel_limit = (
                min(parallel_limit, max_sessions)
                if parallel_limit is not None
                else max_sessions
            )

        max_parallel_capacity = (
            float("inf")
            if parallel_limit is None
            else max(0, parallel_limit - parallel_buffer)
        )

        queue_limit = status.queued_allowed if status.queued_allowed > 0 else None
        if queue_limit is not None:
            queue_limit = max(0, queue_limit - queue_buffer)
        max_queue_capacity = float("inf") if queue_limit is None else queue_limit

        if max_parallel_capacity < count and max_queue_capacity < count:
            raise SessionManagementError(
                "Requested %d device(s) exceeds BrowserStack capacity (parallel=%s, queue=%s)."
                % (
                    count,
                    "∞" if max_parallel_capacity == float("inf") else int(max_parallel_capacity),
                    "∞" if max_queue_capacity == float("inf") else int(max_queue_capacity),
                )
            )


