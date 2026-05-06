"""Welcome Back screen locators."""

from ..base_locators import BaseLocators


class WelcomeBackScreenLocators(BaseLocators):
    """Locators for the Welcome Back (returning user) screen."""

    # Screen identification
    LOGIN_SCREEN = BaseLocators.xpath(
        "//*[contains(@resource-id, 'LoginScreen_QMLTYPE')]"
    )
    ONBOARDING_LAYOUT = BaseLocators.id(
        "QGuiApplication.mainWindow.startupOnboardingLayout"
    )

    PASSWORD_INPUT = BaseLocators.xpath(
        "//*[contains(@resource-id, 'loginPasswordInput')]"
    )
    PASSWORD_INPUT_OVERLAY = BaseLocators.xpath(
        "//*[contains(@resource-id, 'loginPasswordInput')]"
    )
    LOGIN_BUTTON = BaseLocators.tid("loginButton")
