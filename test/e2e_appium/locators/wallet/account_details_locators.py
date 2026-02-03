from ..base_locators import BaseLocators


class AccountDetailsLocators(BaseLocators):
    """Locators for the Account Details view (Settings → Wallet → Account)."""

    # Account header
    ACCOUNT_NAME = BaseLocators.resource_id_contains("walletAccountViewAccountName")
    ACCOUNT_IMAGE = BaseLocators.resource_id_contains("walletAccountViewAccountImage")
    EDIT_BUTTON = BaseLocators.resource_id_contains("walletAccountViewEditAccountButton")
    
    # Alternative edit button locator using content-desc
    EDIT_BUTTON_ALT = BaseLocators.xpath(
        "//*[contains(@content-desc, 'Edit account') or contains(@content-desc, 'Edit watched')]"
    )
    
    # Alternative: Account name is displayed as large colored text near the edit button.
    # Note: This uses preceding-sibling which depends on DOM structure. If layout changes
    # and the account name element moves, this locator may break. Prefer ACCOUNT_NAME.
    ACCOUNT_NAME_ALT = BaseLocators.xpath(
        "//*[contains(@content-desc, 'Edit account') or contains(@content-desc, 'Edit watched')]"
        "/preceding-sibling::*[1]"
    )

    # Account details section label
    ACCOUNT_DETAILS_LABEL = BaseLocators.resource_id_contains("AccountDetails_TextLabel")
    
    # Alternative: look for "Account details" text directly
    ACCOUNT_DETAILS_TEXT = BaseLocators.xpath(
        "//*[contains(@text, 'Account details') or contains(@content-desc, 'Account details')]"
    )

    # Account details rows
    BALANCE_ROW = BaseLocators.resource_id_contains("Balance_ListItem")
    ADDRESS_ROW = BaseLocators.resource_id_contains("Address_ListItem")
    KEYPAIR_LABEL = BaseLocators.resource_id_contains("Keypair_TextLabel")
    KEYPAIR_ITEM = BaseLocators.resource_id_contains("KeyPair_Item")
    ORIGIN_ROW = BaseLocators.resource_id_contains("Origin_ListItem")
    DERIVATION_PATH_ROW = BaseLocators.resource_id_contains("DerivationPath_ListItem")
    STORED_ROW = BaseLocators.resource_id_contains("Stored_ListItem")

    # Watch-only specific
    INCLUDE_TOTAL_BALANCE_TOGGLE = BaseLocators.resource_id_contains(
        "includeTotalBalanceListItem"
    )

    # Delete account button
    DELETE_BUTTON = BaseLocators.resource_id_contains("deleteAccountButton")
