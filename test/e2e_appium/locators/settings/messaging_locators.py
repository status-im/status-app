from ..base_locators import BaseLocators, object_name_pred


class MessagingSettingsLocators(BaseLocators):
    CONTACTS_ENTRY = BaseLocators.tid("MessagingView_ContactsListItem_btn")
    CONTACTS_BADGE = BaseLocators.xpath(
        f"//*[{object_name_pred('MessagingView_ContactsListItem_btn')}]//*[{object_name_pred('badge')}]"
    )


