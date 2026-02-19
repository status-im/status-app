from ..base_locators import BaseLocators


class PasswordScreenLocators(BaseLocators):

    # Screen identification
    PASSWORD_SCREEN = BaseLocators.label_contains("Create profile password")

    PASSWORD_INPUT = BaseLocators.xpath(
        "//*[(contains(@resource-id, 'passwordViewNewPassword') "
        "or contains(@name, 'passwordViewNewPassword')) "
        "and not(contains(@resource-id, 'Confirm') or contains(@name, 'Confirm'))]"
    )
    PASSWORD_CONFIRM_INPUT = BaseLocators.xpath(
        "//*[contains(@resource-id, 'passwordViewNewPasswordConfirm') "
        "or contains(@name, 'passwordViewNewPasswordConfirm')]"
    )

    # On Android content-desc contains "[tid:btnConfirmPassword]";
    # on iOS name contains "btnConfirmPassword".
    CONFIRM_PASSWORD_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:btnConfirmPassword]') "
        "or contains(@name, 'btnConfirmPassword')]"
    )

    ONBOARDING_CONTAINER = BaseLocators.object_name_contains(
        "startupOnboardingLayout"
    )
