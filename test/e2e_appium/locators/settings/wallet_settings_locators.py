from ..base_locators import BaseLocators, xpath_string


class WalletSettingsLocators(BaseLocators):
    """Locators for the Wallet Settings view (Settings → Wallet)."""

    # Navigation - Wallet menu item in settings
    # Prefer the stable tid selector; keep resource-id fallback for older builds.
    WALLET_MENU_ITEM = BaseLocators.xpath(
        "//*[contains(@content-desc, '[tid:5-MenuItem]') or contains(@resource-id, '5-MenuItem')]"
    )

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
