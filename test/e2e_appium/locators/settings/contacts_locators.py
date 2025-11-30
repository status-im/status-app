from ..base_locators import BaseLocators


class ContactsSettingsLocators(BaseLocators):
    CONTACTS_TAB = BaseLocators.xpath(
        "//*[contains(@resource-id,'ContactsView_Contacts_Button')]"
    )
    PENDING_TAB = BaseLocators.xpath(
        "//*[contains(@resource-id,'ContactsView_PendingRequest_Button')]"
    )
    PENDING_REQUEST_ROW = BaseLocators.xpath(
        "//android.view.TextView[contains(@resource-id,'ContactPanel')]"
    )
    FIRST_PENDING_ACCEPT_BUTTON = BaseLocators.xpath(
        "(//*[contains(@resource-id,'ContactPanel')]//*[contains(@resource-id,'acceptBtn')])[1]"
    )
    DISMISSED_TAB = BaseLocators.xpath(
        "//*[contains(@resource-id,'ContactsView_DismissedRequest_Button')]"
    )
    BLOCKED_TAB = BaseLocators.xpath(
        "//*[contains(@resource-id,'ContactsView_Blocked_Button')]"
    )
    SEND_CONTACT_REQUEST_BUTTON = BaseLocators.content_desc_contains(
        "[tid:ContactsView_ContactRequest_Button]"
    )
    CONTACT_LIST = BaseLocators.xpath(
        "//*[contains(@resource-id,'ContactListPanel_ListView')]"
    )

    @staticmethod
    def contact_row(identifier_suffix: str) -> tuple:
        escaped = identifier_suffix.replace("'", "\\'")
        xpath = (
            "//android.view.TextView"
            f"[contains(@resource-id,'ContactPanel') and contains(@content-desc,\"{escaped}\")]"
        )
        return BaseLocators.xpath(xpath)

    @staticmethod
    def contact_action_button(identifier: str, object_name: str) -> tuple:
        suffix = identifier.replace("'", "\\'")
        xpath = (
            "//android.view.TextView"
            f"[contains(@resource-id,'ContactPanel') and "
            f"contains(@content-desc,\"{suffix}\")]"
            f"//*[contains(@resource-id,'{object_name}')]"
        )
        return BaseLocators.xpath(xpath)

    @classmethod
    def accept_button(cls, display_name: str) -> tuple:
        return cls.contact_action_button(display_name, "acceptBtn")

    @classmethod
    def chat_button(cls, display_name: str) -> tuple:
        return cls.contact_action_button(display_name, "chatBtn")


