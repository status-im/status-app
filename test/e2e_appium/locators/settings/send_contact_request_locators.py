from ..base_locators import BaseLocators, object_name_pred


class SendContactRequestLocators(BaseLocators):
    MODAL_ROOT = BaseLocators.object_name_contains("SendContactRequestToChatKeyModal")
    CHAT_KEY_INPUT = BaseLocators.xpath(
        f"//*[{object_name_pred('SendContactRequestModal_ChatKey_Input')}]"
        # iOS: input.edit names are not exposed (#22804); match the placeholder.
        " | //*[contains(@name,'SendContactRequestToChatKeyModal') and contains(@name,'statusBaseInput') and starts-with(@label,'Enter chat key')]"
    )
    MESSAGE_INPUT = BaseLocators.xpath(
        f"//*[{object_name_pred('SendContactRequestModal_SayWhoYouAre_Input')}]"
        # iOS: input.edit names are not exposed (#22804); match the placeholder.
        " | //*[contains(@name,'SendContactRequestToChatKeyModal') and contains(@name,'statusBaseInput') and starts-with(@label,'Say who you are')]"
    )
    SEND_BUTTON = BaseLocators.resource_id_contains(
        "SendContactRequestModal_Send_Button"
    )


