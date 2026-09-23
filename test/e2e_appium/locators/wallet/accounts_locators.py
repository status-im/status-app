from ..base_locators import BaseLocators


class WalletAccountsLocators(BaseLocators):
    ADD_ACCOUNT_BUTTON = BaseLocators.resource_id_contains("addAccountButton")
    ALL_ACCOUNTS_BUTTON = BaseLocators.tid("allAccountsBtn")
    ACCOUNT_ROW_ANY = BaseLocators.tid("walletAccountListItem")
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
    KEYCARD_AUTHENTICATE_BUTTON = BaseLocators.tid("keycardPopupBaseSubmitButton")
    KEYCARD_CANCEL_BUTTON = BaseLocators.content_desc_exact("Cancel")
    REMOVE_ACCOUNT_MODAL = BaseLocators.xpath(
        "//*[contains(@resource-id,'RemoveAccountConfirmationPopup')]"
    )
    REMOVE_ACCOUNT_ACK_CHECKBOX = BaseLocators.tid("RemoveAccountPopup-HavePenPaper")
    REMOVE_ACCOUNT_CONFIRM_BUTTON = BaseLocators.tid("RemoveAccountPopup-ConfirmButton")
    REMOVE_ACCOUNT_CANCEL_BUTTON = BaseLocators.tid("RemoveAccountPopup-CancelButton")
    ADD_ACCOUNT_MODAL = BaseLocators.xpath(
        "//*[contains(@resource-id,'AddAccountPopup')]"
    )
    DEFAULT_ACCOUNT_ROW = BaseLocators.tid("walletAccountListItem")
    ACCOUNT_NAME_INPUT = BaseLocators.tid("statusBaseInput")
    ADD_ACCOUNT_PRIMARY = BaseLocators.tid("AddAccountPopup-PrimaryButton")
    EDIT_DERIVATION_BUTTON = BaseLocators.tid("AddAccountPopup-EditDerivationPath")
    RECEIVE_CARD = BaseLocators.tid("receiveCard")
    WALLET_HEADER_ADDRESS = BaseLocators.tid("walletHeaderButton")
    FOOTER_SEND = BaseLocators.tid("walletFooterSendButton")
    FOOTER_RECEIVE = BaseLocators.resource_id_contains("walletFooterReceiveButton")
    FOOTER_BUY = BaseLocators.tid("walletFooterBuyButton")
    FOOTER_SWAP = BaseLocators.tid("walletFooterSwapButton")

    # Add account modal — origin selector
    ORIGIN_SELECTOR = BaseLocators.tid("AddAccountPopup-SelectedOrigin")
    ORIGIN_WATCHED_ADDRESS = BaseLocators.tid(
        "AddAccountPopup-OriginOption-LABEL-OPTION-ADD-WATCH-ONLY-ACC"
    )
    # tid("statusBaseInput") alone matches the account-name input first, and the
    # watch-only section has no accessibility node to narrow the match.
    WATCHED_ADDRESS_INPUT = BaseLocators.tid("AddAccountPopup-WatchOnlyAddress.statusBaseInput")
