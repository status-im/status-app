"""BrowserStack Plan API client used for concurrency and queue insights."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Optional

import requests


logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class BrowserStackPlanStatus:
    """Snapshot of BrowserStack App Automate plan usage."""

    parallel_running: int
    parallel_allowed: int
    queued_sessions: int
    queued_allowed: int
    timestamp: datetime

    @property
    def parallel_saturation(self) -> float:
        if self.parallel_allowed <= 0:
            return 0.0
        return min(1.0, self.parallel_running / self.parallel_allowed)

    @property
    def queue_saturation(self) -> float:
        if self.queued_allowed <= 0:
            return 0.0
        return min(1.0, self.queued_sessions / self.queued_allowed)


class BrowserStackPlanClient:
    """Thin wrapper around BrowserStack's plan API with basic caching."""

    PLAN_ENDPOINT = "https://api-cloud.browserstack.com/app-automate/plan.json"

    def __init__(
        self,
        username: str,
        access_key: str,
        *,
        cache_ttl: int = 10,
    ) -> None:
        self.username = username
        self.access_key = access_key
        self._cache_ttl = max(0, cache_ttl)
        self._cached_status: Optional[BrowserStackPlanStatus] = None
        self._cached_at: Optional[datetime] = None

    def get_plan_status(
        self,
        *,
        force_refresh: bool = False,
        timeout: int = 10,
    ) -> Optional[BrowserStackPlanStatus]:
        """Fetch current plan utilisation details.

        Args:
            force_refresh: Skip cached value even if still valid.
            timeout: HTTP timeout in seconds.

        Returns:
            Parsed plan status or None when unavailable.
        """

        now = datetime.now(timezone.utc)
        if not force_refresh and self._cache_ttl and self._cached_status and self._cached_at:
            if now - self._cached_at <= timedelta(seconds=self._cache_ttl):
                return self._cached_status

        try:
            response = requests.get(
                self.PLAN_ENDPOINT,
                auth=(self.username, self.access_key),
                timeout=timeout,
            )
            response.raise_for_status()
            payload = response.json()
        except requests.RequestException as exc:  # pragma: no cover - network call
            logger.debug("BrowserStack Plan API request failed: %s", exc)
            if force_refresh:
                self._cached_status = None
                self._cached_at = None
            return self._cached_status if not force_refresh else None

        status = BrowserStackPlanStatus(
            parallel_running=int(payload.get("parallel_sessions_running", 0)),
            parallel_allowed=int(payload.get("parallel_sessions_max_allowed", 0)),
            queued_sessions=int(payload.get("queued_sessions", 0)),
            queued_allowed=int(payload.get("queued_sessions_max_allowed", 0)),
            timestamp=now,
        )

        if self._cache_ttl:
            self._cached_status = status
            self._cached_at = now

        return status


__all__ = ["BrowserStackPlanClient", "BrowserStackPlanStatus"]



