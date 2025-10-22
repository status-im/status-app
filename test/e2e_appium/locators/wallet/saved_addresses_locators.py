from ..base_locators import BaseLocators


class SavedAddressesLocators(BaseLocators):
    WALLET_SAVED_ADDRESSES_BUTTON = BaseLocators.content_desc_contains(
        "[tid:savedAddressesBtn]"
    )
    SETTINGS_WALLET_MENU_ITEM = BaseLocators.content_desc_contains("[tid:5-MenuItem]")
    SAVED_ADDRESSES_ITEM = BaseLocators.xpath(
        "//*[contains(@resource-id, 'savedAddressesItem') or contains(@content-desc, 'Saved Addresses')]"
    )
    ADD_NEW_SAVED_ADDRESS_BUTTON_SETTINGS = BaseLocators.xpath(
        '//android.view.View.VirtualChild[@content-desc="Add new address [tid:addNewSavedAddressButton]"]'
    )
    ADD_NEW_SAVED_ADDRESS_BUTTON_WALLET = BaseLocators.xpath(
        '//android.view.View.VirtualChild[@content-desc="Add new address [tid:walletHeaderButton]"]'
    )
    SAVED_ADDRESS_ITEM_ANY = BaseLocators.xpath(
        '//android.view.View.VirtualChild[@resource-id="savedAddressDelegate"]'
    )
    SAVED_ADDRESS_DETAILS_POPUP = BaseLocators.xpath(
        "//*[contains(@resource-id, 'SavedAddressActivityPopup')]"
    )
    POPUP_MENU_BUTTON_GENERIC = BaseLocators.xpath(
        "//*[contains(@resource-id,'SavedAddressActivityPopup')]//*[contains(@resource-id, 'savedAddressView_Delegate_menuButton_')]"
    )
    POPUP_MENU_BUTTON_TID = BaseLocators.content_desc_contains(
        "tid:savedAddressMenuButton"
    )

    @staticmethod
    def row_by_name(name: str) -> tuple:
        return BaseLocators.xpath(
            '//android.view.View.VirtualChild[@resource-id="savedAddressDelegate"]'
            + f"//*[contains(@resource-id, 'savedAddressView_Delegate_{name}')]"
        )

    @staticmethod
    def row_menu_by_name(name: str) -> tuple:
        return BaseLocators.xpath(
            "//android.view.View.VirtualChild["
            + f"contains(@resource-id, 'savedAddressView_Delegate_{name}') and "
            + f"contains(@resource-id, 'savedAddressView_Delegate_menuButton_{name}')"
            + "]"
        )

    @staticmethod
    def popup_menu_by_name(name: str) -> tuple:
        return BaseLocators.xpath(
            "//android.view.View.VirtualChild["
            + "contains(@resource-id,'QGuiApplication.mainWindow.SavedAddressActivityPopup') and "
            + f"contains(@resource-id, 'savedAddressView_Delegate_menuButton_{name}')"
            + "]"
        )

    NAME_INPUT = BaseLocators.xpath(
        '//android.view.View.VirtualChild[@content-desc="Address name [tid:statusBaseInput]"]'
    )
    ADDRESS_INPUT = BaseLocators.xpath(
        '//android.view.View.VirtualChild[@content-desc="Ethereum address [tid:statusBaseInput]"]'
    )
    SAVE_BUTTON = BaseLocators.xpath(
        '//android.view.View.VirtualChild[@content-desc="Add address [tid:addSavedAddress]"]'
    )
    DELETE_SAVED_ADDRESS_ACTION = BaseLocators.xpath(
        "//*[@resource-id and contains(@resource-id, 'deleteSavedAddress') or @content-desc='Remove saved address']"
    )
    CONFIRM_DELETE_BUTTON = BaseLocators.xpath(
        "//*[@resource-id and contains(@resource-id, 'RemoveSavedAddressPopup-ConfirmButton')]"
    )
