from locators.base_locators import BaseLocators


class CreateChatLocators:
    START_CHAT_BUTTON = BaseLocators.object_name_contains("startChatButton")
    RECIPIENT_INPUT = BaseLocators.resource_id_contains("chatRecipientInput")
    CONTACT_REQUEST_MESSAGE_INPUT = BaseLocators.xpath(
        "//android.widget.EditText[contains(@resource-id, 'ProfileSendContactRequestModal_sayWhoYouAreInput')]"
        # iOS: input.edit names are not exposed (#22804); match the placeholder.
        " | //*[contains(@name,'SendContactRequestModal') and contains(@name,'statusBaseInput') and starts-with(@label,'Write a short message telling them who you are')]"
    )
    CONTACT_REQUEST_MESSAGE_PLACEHOLDER = BaseLocators.tid("statusBaseInput")
    CONFIRM_SELECTION_BUTTON = BaseLocators.object_name_contains("inlineSelectorConfirmButton")
    CONTACT_REQUEST_MODAL_ROOT = BaseLocators.tid("ProfileSendContactRequestModal_sendContactRequestButton")
    CONTACT_REQUEST_SEND_BUTTON = BaseLocators.object_name_contains("ProfileSendContactRequestModal_sendContactRequestButton")
    CONTACT_REQUEST_SENT_TOAST = BaseLocators.content_desc_contains(
        "Contact request sent"
    )


