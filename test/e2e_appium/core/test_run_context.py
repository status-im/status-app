"""
TestRunContext - Minimal multi-device orchestration

Creates and manages multiple TestContext instances for scenarios
requiring more than one device (e.g., syncing or cross-user messaging).
"""

import copy
from typing import List, Optional, Dict, Any

from config.logging_config import get_logger
from core.test_context import TestContext, TestConfiguration
from core.config_manager import ConfigurationManager


class TestRunContext:
    __test__ = False

    def __init__(self, contexts: List[TestContext]):
        self.contexts = contexts
        self.logger = get_logger("test_run_context")

    @classmethod
    def create(
        cls,
        number: int = 2,
        environment: str = "browserstack",
        config: Optional[TestConfiguration] = None,
        device_overrides: Optional[List[Dict[str, Any]]] = None,
        device_tags: Optional[List[str]] = None,
    ) -> "TestRunContext":
        """
        Create N TestContexts.

        - If device_overrides provided: use those devices directly (first N)
        - Else if device_tags provided: filter YAML devices by tags, take first N
        - Else: create N contexts using the default device from env config
        """
        contexts: List[TestContext] = []

        selected_devices: List[Dict[str, Any]] = []
        if device_overrides:
            selected_devices = device_overrides[:number]
        elif device_tags:
            # Load env YAML and filter devices by tags
            cfg_mgr = ConfigurationManager()
            env_cfg = cfg_mgr.load_environment(environment)
            all_devices = env_cfg.available_devices or []

            def has_tags(dev):
                tags = set(dev.get("tags", []))
                return all(tag in tags for tag in device_tags)

            selected_devices = [d for d in all_devices if has_tags(d)][:number]

        for i in range(number):
            if config:
                per_ctx_config = copy.deepcopy(config)
            else:
                per_ctx_config = TestConfiguration(environment=environment)
            if i < len(selected_devices):
                # Pass device override into TestContext via custom_config
                per_ctx_config.device_override = selected_devices[i]
            ctx = TestContext(environment=environment).initialize(per_ctx_config)
            contexts.append(ctx)
        return cls(contexts)

    def cleanup(self) -> None:
        for i, ctx in enumerate(self.contexts):
            try:
                ctx.cleanup()
            except Exception as e:
                self.logger.debug(f"Cleanup warning for context {i}: {e}")

    def report_all(
        self,
        status: str,
        error_message: Optional[str] = None,
        test_name: Optional[str] = None,
    ) -> None:
        for ctx in self.contexts:
            ctx.report(status, error_message=error_message, test_name=test_name)

    # Convenience iterators
    def __iter__(self):
        return iter(self.contexts)
