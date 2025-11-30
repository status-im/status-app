"""
SessionPool - Async parallel session creation for multi-device tests.

Manages lifecycle of multiple Appium sessions with parallel creation
capability and automatic cleanup.
"""

import asyncio
import json
from dataclasses import dataclass
from typing import Any, Callable, Dict, List, Optional, Tuple, TypeVar
T = TypeVar("T")


from appium.webdriver.webdriver import WebDriver

from config.logging_config import get_logger
from core.config_manager import ConfigurationManager
from core.environment import EnvironmentConfig
from core.session_manager import SessionManager
from utils.exceptions import SessionManagementError
from core.capacity_reserver import (
    CapacityReserver,
    create_plan_client,
    get_shared_pending_counter,
)


@dataclass
class PoolConfig:
    """Configuration bundle for SessionPool creation parameters."""

    environment: str = "browserstack"
    env_config: Optional[EnvironmentConfig] = None
    device_overrides: Optional[List[Dict[str, Any]]] = None
    device_tags: Optional[List[str]] = None
    parallel: bool = True
    queue_throttle_config: Dict[str, Any] = None

    def __post_init__(self):
        throttle_defaults = {
            "enabled": True,
            "poll_interval": 10,
            "timeout": 90,
            "parallel_buffer": 0,
            "queue_buffer": 0,
        }

        if self.queue_throttle_config is None:
            self.queue_throttle_config = dict(throttle_defaults)
        else:
            merged = dict(throttle_defaults)
            for key, value in self.queue_throttle_config.items():
                if key in throttle_defaults:
                    merged[key] = value
            self.queue_throttle_config = merged

    @classmethod
    def from_environment(
        cls,
        environment: str,
        *,
        env_config: Optional[EnvironmentConfig] = None,
        device_overrides: Optional[List[Dict[str, Any]]] = None,
        device_tags: Optional[List[str]] = None,
        parallel: bool = True,
    ) -> "PoolConfig":
        if env_config is None:
            cfg_mgr = ConfigurationManager()
            env_config = cfg_mgr.load_environment(environment)

        queue_throttle_config = None
        if env_config and hasattr(env_config, "execution"):
            if "queue_throttle" in env_config.execution:
                raw_throttle = env_config.execution["queue_throttle"]
                queue_throttle_config = {
                    key: raw_throttle[key]
                    for key in ("enabled", "poll_interval", "timeout", "parallel_buffer", "queue_buffer")
                    if key in raw_throttle
                }

        return cls(
            environment=environment,
            env_config=env_config,
            device_overrides=list(device_overrides) if device_overrides else None,
            device_tags=list(device_tags) if device_tags else None,
            parallel=parallel,
            queue_throttle_config=queue_throttle_config,
        )


class SessionPool:
    """
    Manages lifecycle of multiple Appium sessions.
    Creates, tracks, and cleans up sessions with parallel creation support.
    """

    __test__ = False

    def __init__(
        self,
        environment: str = "browserstack",
        *,
        config: Optional[PoolConfig] = None,
    ):
        if config is not None and environment != "browserstack":
            raise ValueError("Provide either environment or config when creating SessionPool, not both.")

        self.config = config or PoolConfig.from_environment(environment)
        self.environment = self.config.environment
        self.logger = get_logger("session_pool")
        self._sessions: Dict[str, Tuple[SessionManager, WebDriver]] = {}
        self._created = False
        self.env_config = self.config.env_config

        concurrency_limits = {"max_sessions": 1, "per_device_limit": 1}
        if self.env_config:
            concurrency_limits = self.env_config.concurrency_limits()

        plan_client = create_plan_client(self.env_config)
        shared_counter = get_shared_pending_counter()
        self.capacity_reserver = CapacityReserver(
            plan_client=plan_client,
            concurrency_limits=concurrency_limits,
            throttle_config=self.config.queue_throttle_config,
            shared_pending_counter=shared_counter,
            logger=self.logger,
        )

    async def _run_in_executor(
        self,
        loop: asyncio.AbstractEventLoop,
        func: Callable[[], T],
    ) -> T:
        """Execute blocking work in the provided event loop executor."""
        return await loop.run_in_executor(None, func)

    async def create_sessions(
        self,
        count: int,
        device_configs: Optional[List[Dict[str, Any]]] = None,
        device_tags: Optional[List[str]] = None,
        device_overrides: Optional[List[Dict[str, Any]]] = None,
        parallel: Optional[bool] = None,
        test_nodeid: Optional[str] = None,
    ) -> Dict[str, WebDriver]:
        """
        Create N sessions, optionally in parallel.

        Args:
            count: Number of sessions to create
            device_configs: Optional list of device config dicts (one per session)
            device_tags: Optional list of tags to filter devices by
            device_overrides: Optional list of device override dicts (one per session)
            parallel: If True, create sessions concurrently; if False, create sequentially

        Returns:
            Dict mapping device names (e.g., "device_0", "device_1") to WebDriver instances

        Raises:
            SessionManagementError: If session creation fails after retries
        """
        if self._created:
            raise SessionManagementError("Sessions already created. Create new SessionPool instance.")

        if count < 1:
            raise ValueError(f"count must be >= 1, got {count}")

        device_overrides = (
            device_overrides
            if device_overrides is not None
            else (
                list(self.config.device_overrides)
                if self.config.device_overrides is not None
                else None
            )
        )

        device_tags = (
            device_tags
            if device_tags is not None
            else (
                list(self.config.device_tags)
                if self.config.device_tags is not None
                else None
            )
        )

        device_configs = (
            device_configs
            if device_configs is not None
            else (
                list(device_overrides) if device_overrides is not None else None
            )
        )

        parallel_flag = self.config.parallel if parallel is None else parallel

        self.logger.info(
            "Creating %d session(s) (parallel=%s) for environment %s",
            count,
            parallel_flag,
            self.environment,
        )

        capacity_reserved = False
        try:
            await self.capacity_reserver.reserve(count)
            capacity_reserved = True
            if parallel_flag:
                drivers = await self._create_parallel(
                    count, device_configs, device_tags, device_overrides, test_nodeid
                )
            else:
                drivers = await self._create_sequential(
                    count, device_configs, device_tags, device_overrides, test_nodeid
                )

            self._created = True
            self.logger.info("Successfully created %d session(s)", len(drivers))
            return drivers

        except Exception as e:
            self.logger.error("Failed to create sessions: %s", e)
            await self.cleanup(graceful=True)
            raise SessionManagementError(
                f"Failed to create {count} session(s): {e}"
            ) from e
        finally:
            if capacity_reserved:
                await self.capacity_reserver.release(count)

    async def _create_parallel(
        self,
        count: int,
        device_configs: Optional[List[Dict[str, Any]]],
        device_tags: Optional[List[str]],
        device_overrides: Optional[List[Dict[str, Any]]],
        test_nodeid: Optional[str] = None,
    ) -> Dict[str, WebDriver]:
        """Create all sessions concurrently using asyncio."""
        self.logger.debug("Creating %d sessions in parallel", count)

        tasks = [
            self._create_single_session(
                device_index=i,
                device_config=device_configs[i] if device_configs and i < len(device_configs) else None,
                device_tags=device_tags,
                device_override=device_overrides[i] if device_overrides and i < len(device_overrides) else None,
                test_nodeid=test_nodeid,
            )
            for i in range(count)
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)

        drivers: Dict[str, WebDriver] = {}
        errors: List[Tuple[int, Exception]] = []

        for i, result in enumerate(results):
            device_name = f"device_{i}"
            if isinstance(result, Exception):
                errors.append((i, result))
                self.logger.error("Failed to create session %d: %s", i, result)
            else:
                session_manager, driver = result
                self._set_session_name(session_manager, driver, device_name, test_nodeid)
                drivers[device_name] = driver
                self._sessions[device_name] = (session_manager, driver)

        if errors:
            self.logger.error(
                "Failed to create %d out of %d sessions",
                len(errors),
                count,
            )
            await self.cleanup(graceful=True)
            error_messages = [f"device_{idx}: {str(exc)}" for idx, exc in errors]
            raise SessionManagementError(
                f"Failed to create {len(errors)} out of {count} session(s). "
                f"Errors: {'; '.join(error_messages)}"
            ) from errors[0][1]

        return drivers

    async def _create_sequential(
        self,
        count: int,
        device_configs: Optional[List[Dict[str, Any]]],
        device_tags: Optional[List[str]],
        device_overrides: Optional[List[Dict[str, Any]]],
        test_nodeid: Optional[str] = None,
    ) -> Dict[str, WebDriver]:
        """Create sessions one at a time."""
        self.logger.debug("Creating %d sessions sequentially", count)

        drivers: Dict[str, WebDriver] = {}

        for i in range(count):
            device_name = f"device_{i}"
            try:
                session_manager, driver = await self._create_single_session(
                    device_index=i,
                    device_config=device_configs[i] if device_configs and i < len(device_configs) else None,
                    device_tags=device_tags,
                    device_override=device_overrides[i] if device_overrides and i < len(device_overrides) else None,
                    test_nodeid=test_nodeid,
                )
                self._set_session_name(session_manager, driver, device_name, test_nodeid)
                drivers[device_name] = driver
                self._sessions[device_name] = (session_manager, driver)
                self.logger.debug("Created session %d: %s", i, device_name)

            except Exception as e:
                self.logger.error("Failed to create session %d: %s", i, e)
                await self.cleanup(graceful=True)
                raise SessionManagementError(
                    f"Failed to create session {i} (device {device_name}): {e}"
                ) from e

    async def _create_single_session(
        self,
        device_index: int,
        device_config: Optional[Dict[str, Any]] = None,
        device_tags: Optional[List[str]] = None,
        device_override: Optional[Dict[str, Any]] = None,
        test_nodeid: Optional[str] = None,
    ) -> Tuple[SessionManager, WebDriver]:
        """
        Create a single session with retry logic for queue errors.

        This method runs in an executor to allow parallel execution
        since SessionManager operations are synchronous.
        """
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = asyncio.get_event_loop()

        def _create():
            try:
                session_manager = SessionManager(
                    environment=self.environment,
                    device_override=device_override or device_config,
                    device_tags=device_tags,
                )
                driver = session_manager.get_driver()
                return session_manager, driver

            except Exception as e:
                self.logger.error(
                    "Error creating session for device_index %d: %s",
                    device_index,
                    e,
                )
                raise SessionManagementError(
                    f"Failed to create session for device_index {device_index}: {e}"
                ) from e

        # Simple retry for queue errors (single retry with fixed delay)
        try:
            return await self._run_in_executor(loop, _create)
        except SessionManagementError as e:
            error_message = str(e).lower()
            is_queue_error = (
                "queue" in error_message or
                "browserstack_queue_size_exceeded" in error_message
            )

            if is_queue_error:
                self.logger.warning(
                    "Queue error on device %d, retrying after 5s: %s",
                    device_index,
                    e,
                )
                await asyncio.sleep(5)
                return await self._run_in_executor(loop, _create)
            raise

    def _set_session_name(
        self,
        session_manager: SessionManager,
        driver: WebDriver,
        device_name: str,
        test_nodeid: Optional[str],
    ) -> None:
        """Set BrowserStack session name for a device."""
        if not test_nodeid:
            return
        from utils.test_name_formatter import format_test_name_for_browserstack
        test_name = format_test_name_for_browserstack(test_nodeid, device_name)
        session_manager.metadata.test_name = test_name
        try:
            payload = json.dumps({
                "action": "setSessionName",
                "arguments": {"name": test_name},
            })
            driver.execute_script(f"browserstack_executor: {payload}")
        except Exception as e:
            self.logger.debug("Failed to set session name for %s: %s", device_name, e)

    async def cleanup(self, graceful: bool = True) -> None:
        """
        Clean up all sessions, handling errors gracefully.

        Args:
            graceful: If True, continue cleanup even if some sessions fail
        """
        if not self._sessions:
            return

        self.logger.info("Cleaning up %d session(s)", len(self._sessions))

        async def _cleanup_session(
            device_name: str, session_manager: SessionManager, driver: WebDriver
        ) -> Optional[Exception]:
            try:
                session_manager.cleanup_driver()
                self.logger.debug("Cleaned up session: %s", device_name)
                return None

            except Exception as e:
                self.logger.warning(
                    "Error cleaning up session %s: %s",
                    device_name,
                    e,
                )
                if not graceful:
                    raise
                return e

        tasks = [
            _cleanup_session(device_name, session_manager, driver)
            for device_name, (session_manager, driver) in self._sessions.items()
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)

        errors = [r for r in results if r is not None]
        if errors:
            self.logger.warning(
                "Encountered %d error(s) during cleanup (graceful=%s)",
                len(errors),
                graceful,
            )

        self._sessions.clear()
        self._created = False
        self.logger.info("Cleanup completed")

    def get_driver(self, device_name: str) -> Optional[WebDriver]:
        """Get driver for a specific device by name."""
        if device_name not in self._sessions:
            return None
        return self._sessions[device_name][1]

    def get_session_manager(self, device_name: str) -> Optional[SessionManager]:
        """Get session manager for a specific device by name."""
        if device_name not in self._sessions:
            return None
        return self._sessions[device_name][0]

    @property
    def session_count(self) -> int:
        """Return number of active sessions."""
        return len(self._sessions)

    @property
    def device_names(self) -> List[str]:
        """Return list of device names."""
        return list(self._sessions.keys())

