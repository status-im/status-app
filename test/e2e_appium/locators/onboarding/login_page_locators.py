from ..base_locators import BaseLocators, object_name_pred


class LoginPageLocators(BaseLocators):

    # Screen identification
    LOGIN_PAGE = BaseLocators.content_desc_contains("Log in")

    ENTER_RECOVERY_PHRASE_BUTTON = BaseLocators.accessibility_id(
        "Enter recovery phrase"
    )
    LOG_IN_BY_SYNCING_BUTTON = BaseLocators.accessibility_id("Log in by syncing")
    LOG_IN_WITH_KEYCARD_BUTTON = BaseLocators.accessibility_id("Log in with Keycard")

    BACK_BUTTON = BaseLocators.id(
        "QGuiApplication.mainWindow.startupOnboardingLayout.StatusBackButton_QMLTYPE_412_QML_2616"
    )

    ONBOARDING_FRAME = (
        BaseLocators.BY_XPATH,
        f"//*[{object_name_pred('OnboardingFrame_QMLTYPE')}]",
    )
    BUTTON_FRAME = (
        BaseLocators.BY_XPATH,
        f"//*[{object_name_pred('OnboardingButtonFrame_QMLTYPE')}]",
    )
