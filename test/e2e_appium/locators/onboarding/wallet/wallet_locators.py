from ...base_locators import BaseLocators


class WalletLocators(BaseLocators):
    WALLET_HEADER = BaseLocators.content_desc_contains("walletHeader")
    WALLET_FOOTER_SEND_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id, 'walletFooterSendButton')]"
    )
    ASSETS_TAB = BaseLocators.text_contains("Assets")
    ACTIVITY_TAB = BaseLocators.text_contains("Activity")

    ACCOUNT_NAME_ANY = BaseLocators.xpath(
        "//*[contains(@resource-id, 'Account') or contains(@text, 'Account')]"
    )
    BALANCE_ANY = BaseLocators.xpath(
        "//*[contains(@text, 'ETH') or contains(@text, 'USD')]"
    )

    SAVED_ADDRESSES_BUTTON = BaseLocators.content_desc_contains(
        "[tid:savedAddressesBtn]"
    )
    ADD_NEW_ADDRESS_BUTTON = BaseLocators.xpath(
        "//*[contains(@resource-id, 'walletHeaderButton') or @content-desc='Add new address']"
    )
    WALLET_HEADER_ADDRESS = BaseLocators.content_desc_contains(
        "[tid:walletHeaderButton]"
    )

    # Account selection
    ACCOUNT_1_BY_TEXT = BaseLocators.xpath(
        "//*[contains(@text, 'Account 1') or contains(@content-desc, 'Account 1')]"
    )
    ACCOUNT_LIST_ITEM_ANY = BaseLocators.xpath(
        "//*[contains(@resource-id, 'walletAccountListItem')]"
    )
