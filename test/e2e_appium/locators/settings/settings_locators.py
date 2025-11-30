from ..base_locators import BaseLocators


class SettingsLocators(BaseLocators):

    # TODO: Replace fallbacks with accessibility_id/tid

    LEFT_PANEL_CONTAINER = BaseLocators.xpath(
        "//*[contains(@resource-id, 'Settings')] | //*[@content-desc='Settings']"
    )

    # SettingsList.qml sets objectName: model.subsection + "-MenuItem"; backUpSeed subsection is 19
    BACKUP_RECOVERY_MENU_ITEM = BaseLocators.content_desc_contains("[tid:101-MenuItem]")

    PROFILE_MENU_ITEM = BaseLocators.xpath("//*[contains(@resource-id,'0-MenuItem')]")
    PASSWORD_MENU_ITEM = BaseLocators.content_desc_contains("[tid:1-MenuItem]")
    PASSWORD_MENU_ITEM_TEXT = BaseLocators.text_contains("Password")
    MESSAGING_MENU_ITEM = BaseLocators.content_desc_contains("[tid:4-MenuItem]")
    CONTACTS_MENU_ITEM = BaseLocators.content_desc_contains("[tid:2-MenuItem]")

    SIGN_OUT_AND_QUIT = BaseLocators.text_contains("Sign out & Quit")
    SIGN_OUT_AND_QUIT_ALT = BaseLocators.xpath(
        "//*[contains(@content-desc, 'Sign out') and contains(@content-desc, 'Quit')] | //*[contains(@text, 'Sign out') and contains(@text, 'Quit')]"
    )

    CONFIRM_SIGN_OUT = BaseLocators.text_contains("Sign out")
    CONFIRM_QUIT = BaseLocators.text_contains("Quit")
