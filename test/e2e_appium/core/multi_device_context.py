import asyncio
from typing import Dict, List, Optional, Set

from config.logging_config import get_logger
from core.device_context import DeviceContext
from fixtures.onboarding_fixture import OnboardingConfig
from core.models import TestUser
from utils.exceptions import SessionManagementError


class MultiDeviceContext:

    __test__ = False

    def __init__(self, contexts: Dict[str, DeviceContext]):
        if not contexts:
            raise ValueError("contexts dict cannot be empty")

        self.contexts = contexts
        self.device_names = list(contexts.keys())
        self.logger = get_logger("multi_device_context")
        self._failed_devices: Set[str] = set()

        self.logger.debug("Initialized MultiDeviceContext with %d device(s)", len(contexts))

    def __getitem__(self, key: str) -> DeviceContext:
        if key not in self.contexts:
            raise KeyError(
                f"Device '{key}' not found. Available devices: {self.device_names}"
            )
        return self.contexts[key]

    def __iter__(self):
        """Iterate over DeviceContext instances."""
        return iter(self.contexts.values())

    def __len__(self) -> int:
        return len(self.contexts)

    def mark_device_failed(self, device_id: str, reason: Optional[str] = None) -> None:
        if device_id not in self._failed_devices:
            self._failed_devices.add(device_id)
            self.logger.warning(
                "Device %s marked as failed%s",
                device_id,
                f": {reason}" if reason else "",
            )

    def is_device_failed(self, device_id: str) -> bool:
        return device_id in self._failed_devices

    async def onboard_users_parallel(
        self,
        configs: Optional[List[OnboardingConfig]] = None,
        display_names: Optional[List[str]] = None,
        passwords: Optional[List[str]] = None,
        *,
        require_all: bool = True,
    ) -> List[TestUser]:
        device_count = len(self.contexts)
        device_list = list(self.contexts.values())

        if configs and len(configs) != device_count:
            raise ValueError(
                f"configs length ({len(configs)}) must match device count ({device_count})"
            )

        if display_names and len(display_names) != device_count:
            raise ValueError(
                f"display_names length ({len(display_names)}) must match device count ({device_count})"
            )

        if passwords and len(passwords) != device_count:
            raise ValueError(
                f"passwords length ({len(passwords)}) must match device count ({device_count})"
            )

        self.logger.info(
            "Onboarding %d user(s) in parallel across %d device(s) (require_all=%s)",
            device_count,
            device_count,
            require_all,
        )

        tasks = []
        device_mapping = []
        for i, device_context in enumerate(device_list):
            config = configs[i] if configs else None
            display_name = display_names[i] if display_names else None
            password = passwords[i] if passwords else None

            task = device_context.onboard_user(
                config=config,
                display_name=display_name,
                password=password,
            )
            tasks.append(task)
            device_mapping.append(device_context)

        results = await asyncio.gather(*tasks, return_exceptions=True)

        users: List[Optional[TestUser]] = []
        failures = []
        for i, result in enumerate(results):
            device_context = device_mapping[i]
            if isinstance(result, Exception):
                failures.append((device_context.device_id, result))
                self.mark_device_failed(device_context.device_id, str(result))
                users.append(None)
            else:
                users.append(result)

        if failures:
            failure_messages = [
                f"device {device_id}: {str(exc)}" for device_id, exc in failures
            ]
            error_msg = f"Failed to onboard {len(failures)} device(s): {'; '.join(failure_messages)}"
            self.logger.error("Failed to onboard users in parallel: %s", error_msg)

            if require_all:
                raise SessionManagementError(error_msg) from failures[0][1]

            successful_count = len([u for u in users if u is not None])
            self.logger.warning(
                "Onboarding completed with %d failure(s), %d success(es)",
                len(failures),
                successful_count,
            )

        self.logger.info("Successfully onboarded %d user(s)", len([u for u in users if u is not None]))
        return users

    def get_failed_devices(self) -> Set[str]:
        return self._failed_devices.copy()

    def get_successful_devices(self) -> List[str]:
        return [
            device_id
            for device_id, ctx in self.contexts.items()
            if ctx.user is not None and device_id not in self._failed_devices
        ]
