from ..base_locators import BaseLocators


class SavedAddressesLocators(BaseLocators):
    WALLET_SAVED_ADDRESSES_BUTTON = BaseLocators.content_desc_contains(
        "[tid:savedAddressesBtn]"
    )
    SETTINGS_WALLET_MENU_ITEM = BaseLocators.content_desc_contains("[tid:5-MenuItem]")
    SAVED_ADDRESSES_ITEM = BaseLocators.resource_id_contains(
        "savedAddressesItem"
    )
    ADD_NEW_SAVED_ADDRESS_BUTTON_SETTINGS = BaseLocators.content_desc_contains(
        "[tid:addNewSavedAddressButton]"
    )
    ADD_NEW_SAVED_ADDRESS_BUTTON_WALLET = BaseLocators.content_desc_contains(
        "[tid:walletHeaderButton]"
    )
    SAVED_ADDRESS_ITEM_ANY = BaseLocators.resource_id_contains("savedAddressView_Delegate")
    SAVED_ADDRESS_DETAILS_POPUP = BaseLocators.resource_id_contains(
        "SavedAddressActivityPopup"
    )
    POPUP_MENU_BUTTON_GENERIC = BaseLocators.xpath(
        "//*[contains(@resource-id,'SavedAddressActivityPopup')]//*[contains(@resource-id, 'savedAddressView_Delegate_menuButton_')]"
    )
    @staticmethod
    def row_by_name(name: str) -> tuple:
        return BaseLocators.resource_id_contains(f"savedAddressView_Delegate_{name}")

    @staticmethod
    def row_menu_by_name(name: str) -> tuple:
        return BaseLocators.content_desc_contains(
            f"[tid:savedAddressView_Delegate_menuButton_{name}]"
        )

    @staticmethod
    def popup_menu_by_name(name: str) -> tuple:
        return BaseLocators.content_desc_contains(
            f"[tid:savedAddressView_Delegate_menuButton_{name}]"
        )

    @staticmethod
    def popup_header_by_name(name: str) -> tuple:
        return BaseLocators.content_desc_contains(f"[tid:{name}]")

    NAME_INPUT = BaseLocators.resource_id_contains("savedAddressNameInput")
    ADDRESS_INPUT = BaseLocators.resource_id_contains(
        "savedAddressAddressInputEdit"
    )
    SAVE_BUTTON = BaseLocators.content_desc_contains("[tid:addSavedAddress]")
    
    DELETE_SAVED_ADDRESS_ACTION = BaseLocators.xpath(
        "//*[contains(@content-desc,'Remove saved address') or contains(@resource-id,'deleteSavedAddress')]"
    )
    CONFIRM_DELETE_BUTTON = BaseLocators.xpath(
        "//*[contains(@content-desc,'Remove saved address') or contains(@resource-id,'RemoveSavedAddressPopup-ConfirmButton')]"
    )
