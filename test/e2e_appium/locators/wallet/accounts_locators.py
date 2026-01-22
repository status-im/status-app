from ..base_locators import BaseLocators


class WalletAccountsLocators(BaseLocators):
    ADD_ACCOUNT_BUTTON = BaseLocators.resource_id_contains("addAccountButton")
    ALL_ACCOUNTS_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id,'allAccountsBtn')]"
    )
    ACCOUNT_ROW_ANY = BaseLocators.xpath(
        "//*[contains(@resource-id,'walletAccountListItem')]"
    )
    ACCOUNT_CONTEXT_MENU = BaseLocators.xpath(
        "//*[contains(@resource-id,'AccountContextMenu')]"
    )
    ACCOUNT_MENU_DELETE = BaseLocators.xpath(
        "//*[@content-desc='Delete' or contains(@resource-id,'AccountMenu-DeleteAction')]"
    )
    KEYCARD_POPUP = BaseLocators.xpath(
        "//*[contains(@resource-id,'KeycardPopup')]"
    )
    KEYCARD_PASSWORD_INPUT = BaseLocators.content_desc_exact("Password")
    KEYCARD_PASSWORD_INPUT_FALLBACK = BaseLocators.xpath(
        "//*[contains(@resource-id,'keycardPasswordInput')]"
    )
    KEYCARD_AUTHENTICATE_BUTTON = BaseLocators.content_desc_contains(
        "Authenticate"
    )
    KEYCARD_CANCEL_BUTTON = BaseLocators.content_desc_exact("Cancel")
    REMOVE_ACCOUNT_MODAL = BaseLocators.xpath(
        "//*[contains(@resource-id,'RemoveAccountConfirmationPopup')]"
    )
    REMOVE_ACCOUNT_ACK_CHECKBOX = BaseLocators.xpath(
        "//*[contains(@resource-id,'RemoveAccountPopup-HavePenPaper')]"
    )
    REMOVE_ACCOUNT_CONFIRM_BUTTON = BaseLocators.content_desc_contains(
        "[tid:RemoveAccountPopup-ConfirmButton]"
    )
    REMOVE_ACCOUNT_CANCEL_BUTTON = BaseLocators.content_desc_contains(
        "[tid:RemoveAccountPopup-CancelButton]"
    )
    ADD_ACCOUNT_MODAL = BaseLocators.xpath(
        "//*[contains(@resource-id,'AddAccountPopup')]"
    )
    DEFAULT_ACCOUNT_ROW = BaseLocators.content_desc_exact(
        "Account 1 [tid:walletAccountListItem]"
    )
    ACCOUNT_NAME_INPUT = BaseLocators.content_desc_exact(
        "Account name [tid:statusBaseInput]"
    )
    ADD_ACCOUNT_PRIMARY = BaseLocators.content_desc_exact(
        "Add account [tid:AddAccountPopup-PrimaryButton]"
    )
    EDIT_DERIVATION_BUTTON = BaseLocators.content_desc_exact(
        "Edit [tid:AddAccountPopup-EditDerivationPath]"
    )
    RECEIVE_CARD = BaseLocators.xpath("//*[contains(@resource-id,'receiveCard')]")
    WALLET_HEADER_ADDRESS = BaseLocators.content_desc_contains(
        "[tid:walletHeaderButton]"
    )
    FOOTER_SEND = BaseLocators.content_desc_contains("[tid:walletFooterSendButton]")
    FOOTER_BUY = BaseLocators.content_desc_contains("[tid:walletFooterBuyButton]")
    FOOTER_SWAP = BaseLocators.content_desc_contains("[tid:walletFooterSwapButton]")
