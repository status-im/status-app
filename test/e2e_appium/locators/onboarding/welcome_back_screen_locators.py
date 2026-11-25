"""Welcome Back screen locators."""

from ..base_locators import BaseLocators


class WelcomeBackScreenLocators(BaseLocators):
    """Locators for the Welcome Back (returning user) screen."""

    # Screen identification
    LOGIN_SCREEN = BaseLocators.object_name_contains("LoginScreen_QMLTYPE")
    ONBOARDING_LAYOUT = BaseLocators.object_name_contains("startupOnboardingLayout")

    PASSWORD_INPUT = BaseLocators.object_name_contains("loginPasswordInput")
    PASSWORD_INPUT_OVERLAY = BaseLocators.object_name_contains("loginPasswordInput")
    LOGIN_BUTTON = BaseLocators.tid("loginButton")
