from ..base_locators import BaseLocators


class SettingsLocators(BaseLocators):

    # TODO: Replace fallbacks with accessibility_id/tid

    LEFT_PANEL_CONTAINER = BaseLocators.xpath(
        "//*[contains(@resource-id, 'Settings')] | //*[@content-desc='Settings']"
    )

    # SettingsList.qml sets objectName: model.subsection + "-MenuItem"; backUpSeed subsection is 19
    BACKUP_RECOVERY_MENU_ITEM = BaseLocators.tid("101-MenuItem")

    PROFILE_MENU_ITEM = BaseLocators.tid("0-MenuItem")
    PASSWORD_MENU_ITEM = BaseLocators.tid("1-MenuItem")
    PASSWORD_MENU_ITEM_TEXT = BaseLocators.text_contains("Password")
    MESSAGING_MENU_ITEM = BaseLocators.tid("4-MenuItem")
    CONTACTS_MENU_ITEM = BaseLocators.tid("2-MenuItem")

    SIGN_OUT_MENU_ITEM = BaseLocators.tid("100-MenuItem")
    SIGN_OUT_MENU_ITEM_TEXT = BaseLocators.text_contains("Sign out")

    CONFIRM_SIGN_OUT = BaseLocators.tid("signOutConfirmation")
    CONFIRM_SIGN_OUT_TEXT = BaseLocators.text_contains("Sign out")
