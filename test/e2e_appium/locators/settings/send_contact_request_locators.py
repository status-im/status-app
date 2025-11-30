from ..base_locators import BaseLocators


class SendContactRequestLocators(BaseLocators):
    MODAL_ROOT = BaseLocators.xpath(
        "//*[contains(@resource-id,'SendContactRequestToChatKeyModal')]"
    )
    CHAT_KEY_INPUT = BaseLocators.xpath(
        "//*[contains(@resource-id,'SendContactRequestModal_ChatKey_Input')]"
    )
    MESSAGE_INPUT = BaseLocators.xpath(
        "//*[contains(@resource-id,'SendContactRequestModal_SayWhoYouAre_Input')]"
    )
    SEND_BUTTON = BaseLocators.content_desc_contains(
        "[tid:SendContactRequestModal_Send_Button]"
    )


