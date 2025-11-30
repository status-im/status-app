# E2E_Appium Fixtures - Clean Modular Export System
#
# This module provides a clean, organized fixture system for the e2e_appium framework.
# All fixtures are properly exported to avoid import conflicts and circular dependencies.

from __future__ import annotations

import pytest

pytest.register_assert_rewrite("fixtures.multi_device_fixtures")

# Import and re-export core fixtures from the original comprehensive module
from .onboarding_fixture import (
    OnboardingConfig,
    OnboardingFlow,
    OnboardingFlowError,
    onboarding_config,
    custom_onboarding_config,
    onboarding_flow_factory,
    # Seed phrase generation fixtures
    generated_seed_phrase,
    generated_12_word_seed_phrase,
    generated_24_word_seed_phrase,
    onboarding_config_with_seed_phrase,
)

# Import and re-export fixtures from modular system
from .multi_device_fixtures import devices


# Export all fixtures for easy importing
__all__ = [
    # Core onboarding fixtures
    "OnboardingConfig",
    "OnboardingFlow",
    "OnboardingFlowError",
    "onboarding_config",
    "custom_onboarding_config",
    "onboarding_flow_factory",
    # Seed phrase generation fixtures
    "generated_seed_phrase",
    "generated_12_word_seed_phrase",
    "generated_24_word_seed_phrase",
    "onboarding_config_with_seed_phrase",
    # Device fixture
    "devices",
]
