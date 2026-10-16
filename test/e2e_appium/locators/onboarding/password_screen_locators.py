from ..base_locators import BaseLocators, object_name_pred


class PasswordScreenLocators(BaseLocators):

    # Screen identification
    PASSWORD_SCREEN = BaseLocators.label_contains("Create profile password")

    PASSWORD_INPUT = BaseLocators.xpath(
        f"//*[{object_name_pred('passwordViewNewPassword')} and not{object_name_pred('Confirm')}]"
    )
    PASSWORD_CONFIRM_INPUT = BaseLocators.object_name_contains("passwordViewNewPasswordConfirm")

    CONFIRM_PASSWORD_BUTTON = BaseLocators.tid("btnConfirmPassword")

    ONBOARDING_CONTAINER = BaseLocators.object_name_contains(
        "startupOnboardingLayout"
    )
