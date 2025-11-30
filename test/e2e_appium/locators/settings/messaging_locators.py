from ..base_locators import BaseLocators


class MessagingSettingsLocators(BaseLocators):
    CONTACTS_ENTRY = BaseLocators.content_desc_contains(
        "[tid:MessagingView_ContactsListItem_btn]"
    )
    CONTACTS_BADGE = BaseLocators.xpath(
        "//*[contains(@resource-id,'MessagingView_ContactsListItem_btn')]//*[contains(@resource-id,'badge')]"
    )


