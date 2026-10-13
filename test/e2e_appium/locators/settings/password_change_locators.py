from ..base_locators import BaseLocators, object_name_pred


class PasswordChangeLocators(BaseLocators):
    CURRENT_PASSWORD_CONTAINER = BaseLocators.content_desc_exact(
        "Enter current password"
    )
    CURRENT_PASSWORD_INPUT = BaseLocators.object_name_contains("passwordViewCurrentPassword")
    NEW_PASSWORD_INPUT = BaseLocators.xpath(
        f"//*[{object_name_pred('passwordViewNewPassword')} and not({object_name_pred('Confirm')})]"
    )
    CONFIRM_PASSWORD_INPUT = BaseLocators.object_name_contains("passwordViewNewPasswordConfirm")
    CHANGE_PASSWORD_BUTTON = BaseLocators.resource_id_contains(
        "changePasswordModalSubmitButton"
    )


class ChangePasswordModalLocators(BaseLocators):
    # On iOS the modal itself is not an accessibility element; its children's
    # names start with its path, so "inside the modal" is a name prefix there.
    _MODAL = "QGuiApplication.mainWindow.ConfirmChangePasswordModal"
    _IN_MODAL_IOS = f"starts-with(@name,'{_MODAL}.')"
    MODAL_CONTAINER = BaseLocators.xpath(
        f"//*[@resource-id='{_MODAL}' or @name='{_MODAL}' or {_IN_MODAL_IOS}]"
    )
    PRIMARY_BUTTON = BaseLocators.xpath(
        f"//*[@resource-id='{_MODAL}']"
        "//*[contains(@resource-id,'changePasswordModalSubmitButton')]"
        f" | //*[{_IN_MODAL_IOS} and contains(@name,'changePasswordModalSubmitButton')]"
    )
    STATUS_MESSAGE = BaseLocators.xpath(
        f"//*[@resource-id='{_MODAL}']"
        "//*[contains(@resource-id,'statusListItemSubTitle')]"
        f" | //*[{_IN_MODAL_IOS} and contains(@name,'statusListItemSubTitle')]"
    )
