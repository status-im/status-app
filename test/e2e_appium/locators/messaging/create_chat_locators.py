from locators.base_locators import BaseLocators


class CreateChatLocators:
    START_CHAT_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id,'startChatButton')]"
    )
    RECIPIENT_INPUT = BaseLocators.resource_id_contains("chatRecipientInput")
    CONTACT_REQUEST_MESSAGE_INPUT = BaseLocators.xpath(
        "//android.widget.EditText[contains(@resource-id, 'ProfileSendContactRequestModal_sayWhoYouAreInput')]"
    )
    CONTACT_REQUEST_MESSAGE_PLACEHOLDER = BaseLocators.content_desc_contains(
        "[tid:statusBaseInput]"
    )
    CONFIRM_SELECTION_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id,'inlineSelectorConfirmButton')]"
    )
    CONTACT_REQUEST_MODAL_ROOT = BaseLocators.content_desc_contains(
        "[tid:ProfileSendContactRequestModal_sendContactRequestButton]"
    )
    CONTACT_REQUEST_SEND_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id,'ProfileSendContactRequestModal_sendContactRequestButton')]"
    )
    CONTACT_REQUEST_SENT_TOAST = BaseLocators.content_desc_contains(
        "Contact request sent"
    )


