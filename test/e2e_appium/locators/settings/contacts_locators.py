from constants.support_bot import SUPPORT_BOT_CHAT_KEY, SUPPORT_BOT_DISPLAY_NAME

from ..base_locators import BaseLocators, object_name_pred, xpath_string


class ContactsSettingsLocators(BaseLocators):
    CONTACTS_TAB = BaseLocators.object_name_contains("ContactsView_Contacts_Button")
    PENDING_TAB = BaseLocators.object_name_contains("ContactsView_PendingRequest_Button")
    PENDING_REQUEST_ROW = BaseLocators.xpath(
        "//android.view.TextView[contains(@resource-id,'ContactPanel')]"
        " | //*[starts-with(name(),'XCUIElementType')][contains(@name,'ContactPanel')]"
    )
    # Every new profile has a request out to the support bot, so its panel
    # can sit in either list; the peer's is the first panel that is not the bot's.
    _PEER_PANEL = (
        f"//*[{object_name_pred('ContactPanel')}"
        f" and not(contains(@content-desc,'{SUPPORT_BOT_DISPLAY_NAME}'))"
        f" and not({object_name_pred(f'{SUPPORT_BOT_CHAT_KEY}')})]"
    )
    FIRST_PENDING_ACCEPT_BUTTON = BaseLocators.xpath(
        f"({_PEER_PANEL}//*[{object_name_pred('acceptBtn')}])[1]"
    )
    FIRST_CONTACT_CHAT_BUTTON = BaseLocators.xpath(
        f"({_PEER_PANEL}//*[{object_name_pred('chatBtn')}])[1]"
    )
    DISMISSED_TAB = BaseLocators.object_name_contains("ContactsView_DismissedRequest_Button")
    BLOCKED_TAB = BaseLocators.object_name_contains("ContactsView_Blocked_Button")
    SEND_CONTACT_REQUEST_BUTTON = BaseLocators.resource_id_contains(
        "ContactsView_ContactRequest_Button"
    )
    CONTACT_LIST = BaseLocators.object_name_contains("ContactListPanel_ListView")

    @staticmethod
    def contact_row(identifier_suffix: str) -> tuple:
        escaped = identifier_suffix.replace("'", "\\'")
        xpath = (
            "//android.view.TextView"
            f"[contains(@resource-id,'ContactPanel') and contains(@content-desc,\"{escaped}\")]"
            " | //*[starts-with(name(),'XCUIElementType')]"
            f"[contains(@name,'ContactPanel') and contains(@label,\"{escaped}\")]"
        )
        return BaseLocators.xpath(xpath)

    @staticmethod
    def contact_action_button(identifier: str, object_name: str) -> tuple:
        suffix = identifier.replace("'", "\\'")
        xpath = (
            "//android.view.TextView"
            f"[{object_name_pred('ContactPanel')} and "
            f"contains(@content-desc,\"{suffix}\")]"
            f"//*[{object_name_pred(f'{object_name}')}]"
            # iOS: buttons are not row children; take the nearest row above
            # (panel nodes without a [tid:] label; every button has one).
            f" | //XCUIElementTypeButton[contains(@name,'.{object_name}')]"
            "[preceding::*[starts-with(name(),'XCUIElementType')]"
            "[contains(@name,'ContactPanel') and not(contains(@label,'[tid:'))][1]"
            f"[contains(@label,{xpath_string(identifier)})]]"
        )
        return BaseLocators.xpath(xpath)

    @classmethod
    def accept_button(cls, display_name: str) -> tuple:
        return cls.contact_action_button(display_name, "acceptBtn")

    @classmethod
    def chat_button(cls, display_name: str) -> tuple:
        return cls.contact_action_button(display_name, "chatBtn")


