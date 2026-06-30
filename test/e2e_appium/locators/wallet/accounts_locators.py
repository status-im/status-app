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
    ACCOUNT_MENU_EDIT = BaseLocators.xpath(
        "//*[@content-desc='Edit' or contains(@resource-id,'AccountMenu-EditAction')]"
    )
    ACCOUNT_MENU_COPY_ADDRESS = BaseLocators.xpath(
        "//*[contains(@resource-id,'AccountMenu-CopyAddressAction')]"
    )
    KEYCARD_POPUP = BaseLocators.xpath(
        "//*[contains(@resource-id,'AuthenticationPopup') or contains(@resource-id,'KeycardPopup')]"
    )
    KEYCARD_PASSWORD_INPUT = BaseLocators.content_desc_exact("Password")
    KEYCARD_PASSWORD_INPUT_FALLBACK = BaseLocators.xpath(
        "//*[contains(@resource-id,'keycardPasswordInput')]"
    )
    KEYCARD_AUTHENTICATE_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id,'keycardPopupBaseSubmitButton')]"
    )
    KEYCARD_CANCEL_BUTTON = BaseLocators.content_desc_exact("Cancel")
    REMOVE_ACCOUNT_MODAL = BaseLocators.xpath(
        "//*[contains(@resource-id,'RemoveAccountConfirmationPopup')]"
    )
    REMOVE_ACCOUNT_ACK_CHECKBOX = BaseLocators.xpath(
        "//*[contains(@resource-id,'RemoveAccountPopup-HavePenPaper')]"
    )
    REMOVE_ACCOUNT_CONFIRM_BUTTON = BaseLocators.tid("RemoveAccountPopup-ConfirmButton")
    REMOVE_ACCOUNT_CANCEL_BUTTON = BaseLocators.tid("RemoveAccountPopup-CancelButton")
    ADD_ACCOUNT_MODAL = BaseLocators.xpath(
        "//*[contains(@resource-id,'AddAccountPopup')]"
    )
    DEFAULT_ACCOUNT_ROW = BaseLocators.tid("walletAccountListItem")
    ACCOUNT_NAME_INPUT = BaseLocators.tid("statusBaseInput")
    ADD_ACCOUNT_PRIMARY = BaseLocators.tid("AddAccountPopup-PrimaryButton")
    EDIT_DERIVATION_BUTTON = BaseLocators.tid("AddAccountPopup-EditDerivationPath")
    RECEIVE_CARD = BaseLocators.xpath("//*[contains(@resource-id,'receiveCard')]")
    WALLET_HEADER_ADDRESS = BaseLocators.tid("walletHeaderButton")
    FOOTER_SEND = BaseLocators.tid("walletFooterSendButton")
    FOOTER_RECEIVE = BaseLocators.resource_id_contains("walletFooterReceiveButton")
    FOOTER_BUY = BaseLocators.tid("walletFooterBuyButton")
    FOOTER_SWAP = BaseLocators.tid("walletFooterSwapButton")

    # Add account modal — origin selector
    ORIGIN_SELECTOR = BaseLocators.xpath(
        "//*[contains(@resource-id,'AddAccountPopup')]"
        "//*[contains(@content-desc, 'origin') or contains(@resource-id, 'AddAccountPopup-Origin')]"
    )
    ORIGIN_WATCHED_ADDRESS = BaseLocators.xpath(
        "//*[contains(@content-desc, 'Watch-only') or contains(@content-desc, 'Watched address')]"
    )
    WATCHED_ADDRESS_INPUT = BaseLocators.xpath(
        "//*[contains(@resource-id,'AddAccountPopup')]"
        "//*[contains(@resource-id, 'statusBaseInput') or contains(@content-desc, 'address')]"
    )
