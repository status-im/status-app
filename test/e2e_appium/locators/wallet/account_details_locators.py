from ..base_locators import BaseLocators


class AccountDetailsLocators(BaseLocators):
    """Locators for the Account Details view (Settings → Wallet → Account)."""

    # Account header
    ACCOUNT_NAME = BaseLocators.resource_id_contains("walletAccountViewAccountName")
    ACCOUNT_IMAGE = BaseLocators.resource_id_contains("walletAccountViewAccountImage")
    EDIT_BUTTON = BaseLocators.resource_id_contains("walletAccountViewEditAccountButton")

    # Account details section label
    ACCOUNT_DETAILS_LABEL = BaseLocators.resource_id_contains("AccountDetails_TextLabel")

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
