from ..base_locators import BaseLocators


class SimpleSendModalLocators(BaseLocators):
    RECIPIENT_INPUT = BaseLocators.resource_id_contains(
        "RecipientView_SendRecipientInput"
    )
    RECIPIENT_FILLED = BaseLocators.resource_id_contains(
        "RecipientView_RecipientViewDelegate"
    )
    AMOUNT_INPUT = BaseLocators.resource_id_contains("amountToSend_textField")
    TOKEN_SELECTOR = BaseLocators.tid("tokenSelectorButton")
    # AssetView_TokenListItem_* belongs to the wallet page BEHIND the modal —
    # matching it "selects" nothing. The modal's own picker (a StatusDropdown
    # tokenSelectorPanel) names its rows tokenSelectorAssetDelegate_<Asset>.
    ETH_TOKEN_ITEM = BaseLocators.tid("AssetView_TokenListItem_ETH")
    ETH_TOKEN_ITEM_PICKER = BaseLocators.resource_id_contains(
        "tokenSelectorAssetDelegate_Ethereum"
    )
    REVIEW_SEND_BUTTON = BaseLocators.tid("transactionModalFooterButton")
    REVIEW_SEND_BUTTON_FALLBACK = BaseLocators.content_desc_contains("Review Send")
    SCROLL_VIEW = BaseLocators.resource_id_contains("scrollView")


class SendSignModalLocators(BaseLocators):
    SEND_ASSET_VALUE_TID = "sendAssetBoxValue"
    NETWORK_VALUE_TID = "networkBoxValue"
    RECIPIENT_DELEGATE_TID = "recipientDelegate"
    SEND_ASSET_VALUE = BaseLocators.tid(SEND_ASSET_VALUE_TID)
    NETWORK_VALUE = BaseLocators.tid(NETWORK_VALUE_TID)
    RECIPIENT_DELEGATE = BaseLocators.tid(RECIPIENT_DELEGATE_TID)
    SIGN_BUTTON = BaseLocators.tid("signButton")
    REJECT_BUTTON = BaseLocators.tid("rejectButton")
    HEADER_CLOSE_BUTTON = BaseLocators.resource_id_contains("headerActionsCloseButton")
