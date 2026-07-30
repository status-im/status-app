from ..base_locators import BaseLocators, xpath_string


class WalletSettingsLocators(BaseLocators):
    """Locators for the Wallet Settings view (Settings → Wallet)."""

    # Navigation - Wallet menu item in settings
    WALLET_MENU_ITEM = BaseLocators.tid("5-MenuItem")

    # Add new account button in wallet settings main view
    ADD_ACCOUNT_BUTTON = BaseLocators.resource_id_contains(
        "settings_Wallet_MainView_AddNewAccountButton"
    )

    # Account list - Repeater containing keypair delegates
    GENERATED_ACCOUNTS = BaseLocators.resource_id_contains("generatedAccounts")

    # Individual keypair delegate row
    KEYPAIR_DELEGATE = BaseLocators.resource_id_contains("walletKeyPairDelegate")

    # Wallet settings menu items
    NETWORKS_ITEM = BaseLocators.resource_id_contains("networksItem")

    # Networks view — testnet mode toggle + its confirmation popup. The
    # popup title repeats the accept-button text, so prefer the Button class
    # and keep the plain text match as fallback.
    TESTNET_MODE_SWITCH = BaseLocators.tid("testnetModeSwitch")
    TESTNET_CONFIRM_BUTTON = BaseLocators.xpath(
        "//android.widget.Button[@text='Turn on testnet mode'"
        " or contains(@content-desc, 'Turn on testnet mode')]"
    )
    # [last()]: the popup title repeats the button text and precedes it in
    # document order; the accept control is the final match. @clickable
    # keeps non-actionable echoes of the text (title, toast) out of the
    # candidate set so [last()] cannot land on one rendered after the button.
    TESTNET_CONFIRM_BUTTON_FALLBACK = BaseLocators.xpath(
        "(//*[(contains(@text, 'Turn on testnet mode')"
        " or contains(@content-desc, 'Turn on testnet mode'))"
        " and @clickable='true'])[last()]"
    )
    ACCOUNT_ORDER_ITEM = BaseLocators.resource_id_contains("accountOrderItem")
    MANAGE_TOKENS_ITEM = BaseLocators.resource_id_contains("manageTokensItem")
    SAVED_ADDRESSES_ITEM = BaseLocators.resource_id_contains("savedAddressesItem")

    @staticmethod
    def account_row_by_name(name: str) -> tuple:
        """Locator for an account row by name in the wallet settings list.

        WalletAccountDelegate has objectName: account.name, which maps to resource-id.
        The title is also exposed via Accessible.name (content-desc). We check both
        for robustness.

        Uses xpath_string() for proper XPath 1.0 quote escaping.
        """
        escaped = xpath_string(name)
        return BaseLocators.xpath(
            f"//*[contains(@resource-id, {escaped}) or contains(@content-desc, {escaped})]"
        )
