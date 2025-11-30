"""
Locators package for Status Desktop tablet E2E tests.
Contains all element locators organized by screen/feature.
"""

from .base_locators import BaseLocators
from .onboarding.onboarding_locators import OnboardingLocators
from .onboarding.welcome_screen_locators import WelcomeScreenLocators
from .onboarding.analytics_screen_locators import AnalyticsScreenLocators
from .onboarding.create_profile_screen_locators import CreateProfileScreenLocators
from .onboarding.password_screen_locators import PasswordScreenLocators
from .onboarding.loading_screen_locators import LoadingScreenLocators

__all__ = [
    "BaseLocators",
    "OnboardingLocators",
    "WelcomeScreenLocators",
    "AnalyticsScreenLocators",
    "CreateProfileScreenLocators",
    "PasswordScreenLocators",
    "LoadingScreenLocators",
]
