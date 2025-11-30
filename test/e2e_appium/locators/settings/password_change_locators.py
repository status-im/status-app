from ..base_locators import BaseLocators


class PasswordChangeLocators(BaseLocators):
    CURRENT_PASSWORD_CONTAINER = BaseLocators.content_desc_exact(
        "Enter current password"
    )
    CURRENT_PASSWORD_INPUT = BaseLocators.xpath(
        "//*[contains(@resource-id, 'passwordViewCurrentPassword')]"
    )
    NEW_PASSWORD_INPUT = BaseLocators.xpath(
        "//*[contains(@resource-id, 'passwordViewNewPassword') and not(contains(@resource-id, 'Confirm'))]"
    )
    CONFIRM_PASSWORD_INPUT = BaseLocators.xpath(
        "//*[contains(@resource-id, 'passwordViewNewPasswordConfirm')]"
    )
    CHANGE_PASSWORD_BUTTON = BaseLocators.content_desc_contains(
        "[tid:changePasswordModalSubmitButton]"
    )


class ChangePasswordModalLocators(BaseLocators):
    MODAL_CONTAINER = BaseLocators.xpath(
        "//*[@resource-id='QGuiApplication.mainWindow.ConfirmChangePasswordModal']"
    )
    PRIMARY_BUTTON = BaseLocators.xpath(
        "//*[@resource-id='QGuiApplication.mainWindow.ConfirmChangePasswordModal']"
        "//*[contains(@content-desc, 'tid:changePasswordModalSubmitButton')]"
    )
    STATUS_MESSAGE = BaseLocators.xpath(
        "//*[@resource-id='QGuiApplication.mainWindow.ConfirmChangePasswordModal']"
        "//*[contains(@resource-id, 'statusListItemSubTitle')]"
    )
