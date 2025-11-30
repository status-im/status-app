"""
Test for Phase 1 Multi-Device Infrastructure.

Validates SessionPool, DeviceContext, MultiDeviceContext, and fixtures work correctly.
This test exercises the core infrastructure before implementing messaging tests.
"""

import pytest

from config.logging_config import get_logger
from core.device_context import DeviceContext
from core.multi_device_context import MultiDeviceContext
from core.session_pool import PoolConfig, SessionPool
from core.stash_keys import MULTI_DEVICE_MANAGERS_KEY
from core.models import TestUser
from utils.exceptions import SessionManagementError
from utils.generators import generate_account_name
from utils.multi_device_helpers import async_device_step


class TestMultiDeviceInfrastructure:
    """Test suite for multi-device infrastructure components."""

    @pytest.fixture(autouse=True)
    def setup_logger(self):
        self.logger = get_logger(self.__class__.__name__)

    @pytest.mark.skip(reason="Diagnostic only")
    @pytest.mark.critical
    async def test_session_pool_creates_two_sessions(self, test_environment, request):
        """
        Test that SessionPool can create 2 sessions in parallel.

        Validates:
        - SessionPool.create_sessions() works
        - Parallel creation succeeds
        - Both sessions are valid drivers
        - Cleanup works correctly
        """
        from core.config_manager import ConfigurationManager
        cfg_mgr = ConfigurationManager()
        env_cfg = cfg_mgr.load_environment(test_environment)

        pool_config = PoolConfig.from_environment(test_environment, env_config=env_cfg)
        pool = SessionPool(config=pool_config)
        self.logger.info("Testing SessionPool parallel session creation")

        try:
            drivers = await pool.create_sessions(count=2)

            contexts = {
                device_name: DeviceContext(driver=driver, device_id=device_name)
                for device_name, driver in drivers.items()
            }

            multi_ctx = MultiDeviceContext(contexts)
            device_names = list(contexts.keys())

            assert len(drivers) == 2, f"Expected 2 drivers, got {len(drivers)}"
            assert "device_0" in drivers, "device_0 not found in drivers"
            assert "device_1" in drivers, "device_1 not found in drivers"

            driver_0 = drivers["device_0"]
            driver_1 = drivers["device_1"]

            async with async_device_step(multi_ctx, "device_0", "Validate driver_0 session", self.logger):
                assert driver_0 is not None, "driver_0 is None"

            async with async_device_step(multi_ctx, "device_1", "Validate driver_1 session", self.logger):
                assert driver_1 is not None, "driver_1 is None"

            async with async_device_step(multi_ctx, "device_0", "Check unique session ids", self.logger):
                session_id_0 = getattr(driver_0, "session_id", None)
                assert session_id_0 is not None, "driver_0 has no session_id"

            async with async_device_step(multi_ctx, "device_1", "Check unique session ids", self.logger):
                session_id_1 = getattr(driver_1, "session_id", None)
                assert session_id_1 is not None, "driver_1 has no session_id"

            assert session_id_0 != session_id_1, (
                f"Sessions should be different: {session_id_0} vs {session_id_1}"
            )

            self.logger.info(
                "Successfully created 2 parallel sessions: %s, %s",
                session_id_0,
                session_id_1,
            )

        finally:
            # Store for deferred cleanup
            session_managers = {}
            for name in device_names:
                sm = pool.get_session_manager(name)
                if sm:
                    session_managers[name] = sm
            if session_managers:
                request.node.stash.setdefault(MULTI_DEVICE_MANAGERS_KEY, []).append(
                    (session_managers, pool, test_environment)
                )
            else:
                await pool.cleanup()
            self.logger.info("SessionPool cleanup completed")


    @pytest.mark.skip(reason="Diagnostic only")
    @pytest.mark.critical
    async def test_device_context_onboard_user(self, test_environment):
        """
        Test that DeviceContext can onboard a user.

        Validates:
        - DeviceContext wraps driver correctly
        - onboard_user() works
        - User state is tracked correctly
        """
        from core.config_manager import ConfigurationManager
        cfg_mgr = ConfigurationManager()
        env_cfg = cfg_mgr.load_environment(test_environment)
        pool = SessionPool(config=PoolConfig.from_environment(test_environment, env_config=env_cfg))
        self.logger.info("Testing DeviceContext user onboarding")

        try:
            drivers = await pool.create_sessions(count=1, parallel=True)
            driver = drivers["device_0"]

            device_context = DeviceContext(
                driver=driver,
                device_id="device_0",
            )

            assert device_context.driver == driver, "Driver mismatch"
            assert device_context.device_id == "device_0", "Device ID mismatch"
            assert device_context.user is None, "User should be None initially"

            display_name = generate_account_name(12)
            self.logger.info("Onboarding user with display_name: %s", display_name)

            user = await device_context.onboard_user(display_name=display_name)

            assert user is not None, "User should not be None after onboarding"
            assert user.display_name == display_name, (
                f"Display name mismatch: expected {display_name}, got {user.display_name}"
            )
            assert device_context.user == user, "DeviceContext.user should match returned user"
            assert device_context.user.display_name == display_name, (
                "DeviceContext.user.display_name should match"
            )

            self.logger.info(
                "Successfully onboarded user: %s on device %s",
                user.display_name,
                device_context.device_id,
            )

        finally:
            await pool.cleanup()
            self.logger.info("SessionPool cleanup completed")

    @pytest.mark.skip(reason="Diagnostic only")
    @pytest.mark.critical
    async def test_multi_device_context_parallel_onboarding(self, test_environment):
        """
        Test that MultiDeviceContext can onboard users in parallel.

        Validates:
        - MultiDeviceContext manages multiple DeviceContext instances
        - onboard_users_parallel() works
        - Both users are onboarded correctly
        """
        from core.config_manager import ConfigurationManager
        cfg_mgr = ConfigurationManager()
        env_cfg = cfg_mgr.load_environment(test_environment)
        pool = SessionPool(config=PoolConfig.from_environment(test_environment, env_config=env_cfg))
        self.logger.info("Testing MultiDeviceContext parallel onboarding")

        try:
            drivers = await pool.create_sessions(count=2, parallel=True)

            contexts = {
                device_name: DeviceContext(driver=driver, device_id=device_name)
                for device_name, driver in drivers.items()
            }

            multi_ctx = MultiDeviceContext(contexts)

            assert len(multi_ctx) == 2, f"Expected 2 devices, got {len(multi_ctx)}"
            assert multi_ctx["device_0"] is not None, "device_0 context is None"
            assert multi_ctx["device_1"] is not None, "device_1 context is None"

            display_name_1 = generate_account_name(12)
            display_name_2 = generate_account_name(12)

            self.logger.info(
                "Onboarding users in parallel: %s, %s",
                display_name_1,
                display_name_2,
            )

            users = await multi_ctx.onboard_users_parallel(
                display_names=[display_name_1, display_name_2]
            )

            assert len(users) == 2, f"Expected 2 users, got {len(users)}"
            assert users[0].display_name == display_name_1, (
                f"User 1 name mismatch: expected {display_name_1}, got {users[0].display_name}"
            )
            assert users[1].display_name == display_name_2, (
                f"User 2 name mismatch: expected {display_name_2}, got {users[1].display_name}"
            )
            assert users[0].display_name != users[1].display_name, (
                "Users should have different display names"
            )

            assert multi_ctx["device_0"].user == users[0], "device_0 user mismatch"
            assert multi_ctx["device_1"].user == users[1], "device_1 user mismatch"

            self.logger.info(
                "Successfully onboarded 2 users in parallel: %s, %s",
                users[0].display_name,
                users[1].display_name,
            )

        finally:
            await pool.cleanup()
            self.logger.info("SessionPool cleanup completed")

    @pytest.mark.skip(reason="Diagnostic only")
    @pytest.mark.device_count(2)
    async def test_devices_fixture(self, devices):
        """Test that the devices fixture provisions ready-to-use contexts."""

        self.logger.info("Testing devices fixture")

        assert devices is not None, "devices fixture should not be None"
        assert len(devices) == 2, f"Expected 2 devices, got {len(devices)}"

        device_1 = devices["device_0"]
        device_2 = devices["device_1"]

        assert device_1.driver is not None, "device_0.driver should not be None"
        assert device_2.driver is not None, "device_1.driver should not be None"
        assert device_1.driver != device_2.driver, "Drivers should be different instances"

        session_id_1 = getattr(device_1.driver, "session_id", None)
        session_id_2 = getattr(device_2.driver, "session_id", None)

        assert session_id_1 is not None, "device_0 session_id should not be None"
        assert session_id_2 is not None, "device_1 session_id should not be None"
        assert session_id_1 != session_id_2, (
            f"Sessions should be different: {session_id_1} vs {session_id_2}"
        )

        async with async_device_step(devices, device_1, "Validate onboarded user", self.logger):
            assert device_1.user is not None, "device_0 should have onboarded user"

        async with async_device_step(devices, device_2, "Validate onboarded user", self.logger):
            assert device_2.user is not None, "device_1 should have onboarded user"

        async with async_device_step(devices, device_1, "Ensure device display names are unique", self.logger):
            assert device_1.user.display_name != device_2.user.display_name, (
                f"Users should have different names: {device_1.user.display_name} vs {device_2.user.display_name}"
            )

        self.logger.info(
            "devices fixture validated: sessions %s, %s",
            session_id_1,
            session_id_2,
        )

    async def test_onboard_users_parallel_inserts_none_on_failure(self):
        class SuccessfulDevice:
            def __init__(self, device_id: str):
                self.device_id = device_id
                self.user = None

            async def onboard_user(self, **_kwargs):
                self.user = TestUser(display_name=f"{self.device_id}_user")
                return self.user

        class FailingDevice(SuccessfulDevice):
            async def onboard_user(self, **_kwargs):
                raise SessionManagementError("Simulated onboarding failure")

        contexts = {
            "device_0": SuccessfulDevice("device_0"),
            "device_1": FailingDevice("device_1"),
        }

        multi_ctx = MultiDeviceContext(contexts)

        users = await multi_ctx.onboard_users_parallel(require_all=False)

        assert len(users) == 2, "Returned user list should align with device count"
        assert isinstance(users[0], TestUser), "First device should succeed"
        assert users[1] is None, "Failed device slot should contain None"
        assert not multi_ctx.is_device_failed("device_0"), "device_0 should not be marked failed"
        assert multi_ctx.is_device_failed("device_1"), "device_1 should be marked failed"
        assert multi_ctx.get_successful_devices() == ["device_0"], "Only device_0 should be successful"

    @pytest.mark.skip(reason="Diagnostic only")
    async def test_session_pool_throttle_config_defaults(self):
        """Test that PoolConfig has correct default queue_throttle_config values."""
        config = PoolConfig()
        expected_throttle_defaults = {
            "enabled": True,
            "poll_interval": 10,
            "timeout": 90,
            "parallel_buffer": 0,
            "queue_buffer": 0,
        }

        assert config.queue_throttle_config == expected_throttle_defaults, (
            "Expected default queue_throttle_config "
            f"{expected_throttle_defaults}, got {config.queue_throttle_config}"
        )

    @pytest.mark.skip(reason="Diagnostic only")
    async def test_session_pool_throttle_config_from_yaml(self, test_environment):
        """Test that PoolConfig reads queue_throttle_config from YAML configuration."""
        from core.config_manager import ConfigurationManager

        cfg_mgr = ConfigurationManager()
        env_cfg = cfg_mgr.load_environment(test_environment)

        config = PoolConfig.from_environment(test_environment, env_config=env_cfg)

        expected_throttle_config = {
            "enabled": True,
            "poll_interval": 20,
            "timeout": 180,
            "parallel_buffer": 1,
            "queue_buffer": 1,
        }
        assert config.queue_throttle_config == expected_throttle_config, (
            f"Expected queue_throttle_config from YAML {expected_throttle_config}, "
            f"got {config.queue_throttle_config}"
        )

    @pytest.mark.skip(reason="Diagnostic only")
    async def test_session_pool_queue_retry_logic(self):
        """Test that SessionPool retries once on queue errors and succeeds after retry."""
        from unittest.mock import AsyncMock, patch

        config = PoolConfig()
        pool = SessionPool(config=config)

        # Mock the executor helper to simulate queue error followed by success
        with patch.object(SessionPool, "_run_in_executor", new_callable=AsyncMock) as mock_executor:
            mock_executor.side_effect = [
                SessionManagementError("BROWSERSTACK_QUEUE_SIZE_EXCEEDED: Queue full"),
                ("mock_session_manager", "mock_driver"),
            ]

            # Call _create_single_session
            result = await pool._create_single_session(device_index=0)

            # Verify it succeeded after single retry
            assert result == ("mock_session_manager", "mock_driver")
            assert mock_executor.await_count == 2

    @pytest.mark.skip(reason="Legacy infrastructure diagnostics; prefer messaging smoke tests")
    async def test_session_pool_non_queue_error_no_retry(self):
        """Test that SessionPool does not retry on non-queue errors."""
        from unittest.mock import AsyncMock, patch

        config = PoolConfig()
        pool = SessionPool(config=config)

        # Mock the executor helper to simulate a non-queue error
        with patch.object(SessionPool, "_run_in_executor", new_callable=AsyncMock) as mock_executor:
            mock_executor.side_effect = [
                SessionManagementError("Some other error: Connection failed"),
            ]

            # Call _create_single_session and expect it to fail immediately
            with pytest.raises(SessionManagementError, match="Some other error"):
                await pool._create_single_session(device_index=0)

            # Verify executor was called only once (no retries)
            assert mock_executor.await_count == 1

    async def test_capacity_reserver_waits_for_capacity(self, monkeypatch):
        """Ensure CapacityReserver waits when BrowserStack plan indicates saturation."""
        import asyncio
        import tempfile
        from pathlib import Path
        from datetime import datetime, timezone
        from unittest.mock import AsyncMock

        from core.capacity_reserver import CapacityReserver
        from core.shared_counter import FileBasedCounter
        from core.providers.browserstack_plan import BrowserStackPlanStatus

        throttle_config = {
            "enabled": True,
            "poll_interval": 0,
            "timeout": 1,
            "parallel_buffer": 0,
            "queue_buffer": 0,
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            shared_counter = FileBasedCounter(Path(tmpdir) / "counter.txt", initial_value=0)

            reserver = CapacityReserver(
                plan_client=None,
                concurrency_limits={"max_sessions": 5},
                throttle_config=throttle_config,
                shared_pending_counter=shared_counter,
            )

            saturated = BrowserStackPlanStatus(
                parallel_running=5,
                parallel_allowed=5,
                queued_sessions=5,
                queued_allowed=5,
                timestamp=datetime.now(timezone.utc),
            )
            available = BrowserStackPlanStatus(
                parallel_running=3,
                parallel_allowed=5,
                queued_sessions=1,
                queued_allowed=5,
                timestamp=datetime.now(timezone.utc),
            )

            fetch_mock = AsyncMock(side_effect=[saturated, available])
            monkeypatch.setattr(reserver, "_fetch_plan_status", fetch_mock)

            async def immediate_sleep(_):
                return None

            monkeypatch.setattr(asyncio, "sleep", immediate_sleep)

            await reserver.reserve(1)
            assert shared_counter.value == 1
            assert fetch_mock.await_count == 2

            await reserver.release(1)
            assert shared_counter.value == 0

    async def test_capacity_reserver_simple_limit_without_plan(self):
        """CapacityReserver falls back to max_sessions when plan API unavailable."""
        import asyncio
        import tempfile
        from pathlib import Path

        from core.capacity_reserver import CapacityReserver
        from core.shared_counter import FileBasedCounter

        throttle_config = {
            "enabled": True,
            "poll_interval": 0.01,
            "timeout": 0.5,
            "parallel_buffer": 0,
            "queue_buffer": 0,
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            shared_counter = FileBasedCounter(Path(tmpdir) / "counter.txt", initial_value=0)

            reserver = CapacityReserver(
                plan_client=None,
                concurrency_limits={"max_sessions": 1},
                throttle_config=throttle_config,
                shared_pending_counter=shared_counter,
            )

            await reserver.reserve(1)
            assert shared_counter.value == 1

            async def reserve_again():
                await reserver.reserve(1)

            second_task = asyncio.create_task(reserve_again())
            await asyncio.sleep(0.05)
            assert not second_task.done()

            await reserver.release(1)
            await second_task
            assert shared_counter.value == 1

            await reserver.release(1)
            assert shared_counter.value == 0

    async def test_capacity_reserver_request_exceeds_plan_fails_fast(self, monkeypatch):
        import tempfile
        from pathlib import Path
        from datetime import datetime, timezone
        from unittest.mock import AsyncMock

        from core.capacity_reserver import CapacityReserver
        from core.providers.browserstack_plan import BrowserStackPlanStatus
        from core.shared_counter import FileBasedCounter

        throttle_config = {
            "enabled": True,
            "poll_interval": 0,
            "timeout": 5,
            "parallel_buffer": 0,
            "queue_buffer": 0,
        }

        with tempfile.TemporaryDirectory() as tmpdir:
            shared_counter = FileBasedCounter(Path(tmpdir) / "counter.txt", initial_value=0)

            reserver = CapacityReserver(
                plan_client=None,
                concurrency_limits={"max_sessions": 5},
                throttle_config=throttle_config,
                shared_pending_counter=shared_counter,
            )

            plan_status = BrowserStackPlanStatus(
                parallel_running=0,
                parallel_allowed=4,
                queued_sessions=0,
                queued_allowed=4,
                timestamp=datetime.now(timezone.utc),
            )

            monkeypatch.setattr(reserver, "_fetch_plan_status", AsyncMock(return_value=plan_status))

            with pytest.raises(SessionManagementError, match=r"allows only 5 parallel session\(s\)"):
                await reserver.reserve(6)
