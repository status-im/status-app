from objectmaphelper import *
from scripts.global_names import *
from scripts.settings_names import *


# Main:
mainWindow_WalletLayout = {"container": statusDesktop_mainWindow, "type": "WalletLayout", "unnamed": 1, "visible": True}
mainWallet_LeftTab = {"container": statusDesktop_mainWindow, "objectName": "walletLeftTab", "type": "LeftTabView", "visible": True}
mainWallet_Saved_Addresses_Button = {"container": mainWindow_RighPanel, "objectName": "savedAddressesBtn", "type": "StatusFlatButton"}
walletAccounts_StatusListView = {"container": statusDesktop_mainWindow, "objectName": "walletAccountsListView", "type": "StatusListView", "visible": True}
walletAccounts_WalletAccountItem_Placeholder = {"container": walletAccounts_StatusListView, "objectName": "walletAccount-%NAME%", "type": "StatusListItem", "visible": True}
walletAccount_StatusListItem = {"container": walletAccounts_StatusListView, "objectName": RegularExpression("walletAccount*"), "type": "StatusListItem", "visible": True}
mainWallet_Hide_Show_Watch_Only_Button = {"container": statusDesktop_mainWindow, "objectName": "hideShowWatchOnlyButton", "type": "StatusButton", "visible": True}
mainWallet_All_Accounts_Button = {"container": walletAccounts_StatusListView, "objectName": "allAccountsBtn", "type": "Button", "visible": True}

# Context Menu
mainWallet_CopyAddress_MenuItem = {"container": contextMenu_PopupItem, "enabled": True, "objectName": RegularExpression("AccountMenu-CopyAddressAction*"), "type": "StatusMenuItem"}
mainWallet_EditAccount_MenuItem = {"container": contextMenu_PopupItem, "enabled": True, "objectName": RegularExpression("AccountMenu-EditAction*"), "type": "StatusMenuItem"}
mainWallet_DeleteAccount_MenuItem = {"container": contextMenu_PopupItem, "enabled": True, "objectName": RegularExpression("AccountMenu-DeleteAction*"), "type": "StatusMenuItem"}
mainWallet_AddNewAccount_MenuItem = {"container": contextMenu_PopupItem, "enabled": True, "objectName": RegularExpression("AccountMenu-AddNewAccountAction*"), "type": "StatusMenuItem"}
mainWallet_AddWatchOnlyAccount_MenuItem = {"container": contextMenu_PopupItem, "enabled": True, "objectName": RegularExpression("AccountMenu-AddWatchOnlyAccountAction*"), "type": "StatusMenuItem"}

# Saved Address View
mainWindow_SavedAddressesView = {"container": mainWindow_WalletLayout, "type": "SavedAddressesView", "unnamed": 1, "visible": True}
mainWallet_Saved_Addreses_Add_Buttton = {"container": mainWindow_SavedAddressesView, "objectName": "walletHeaderButton", "type": "StatusButton", "visible": True}
mainWallet_Saved_Addreses_List = {"container": mainWindow_SavedAddressesView, "objectName": "SavedAddressesView_savedAddresses", "type": "StatusListView"}
savedAddressView_Delegate = {"container": mainWallet_Saved_Addreses_List, "objectName": RegularExpression("savedAddressView_Delegate*"), "type": "SavedAddressesDelegate", "visible": True}
send_StatusRoundButton = {"container": "", "type": "StatusRoundButton", "unnamed": 1, "visible": True}
savedAddressView_Delegate_menuButton = {"container": "", "objectName": RegularExpression("savedAddressView_Delegate_menuButton*"), "type": "StatusRoundButton", "visible": True}
mainWallet_Saved_Addreses_More_Edit = {"container": statusDesktop_mainWindow, "objectName": "editSavedAddress", "type": "StatusMenuItem"}
mainWallet_Saved_Addreses_More_Delete = {"container": statusDesktop_mainWindow, "objectName": "deleteSavedAddress", "type": "StatusMenuItem"}
mainWallet_Saved_Addreses_More_Confirm_Delete = {"container": statusDesktop_mainWindow, "objectName": "RemoveSavedAddressPopup-ConfirmButton", "type": "StatusButton"}

# Wallet Account View
mainWindow_StatusSectionLayout_ContentItem = {"container": statusDesktop_mainWindow, "objectName": "StatusSectionLayout", "type": "ContentItem", "visible": True}
mainWallet_Account_Name = {"container": mainWindow_StatusSectionLayout_ContentItem, "objectName": "walletHeaderTitle", "type": "StatusBaseText", "visible": True}


# Wallet Account Popup
mainWallet_AddEditAccountPopup_derivationPath = {"container": statusDesktop_mainWindow, "objectName": RegularExpression("AddAccountPopup-PreDefinedDerivationPath*"), "type": "StatusListItem", "visible": True}
addAccountPopup_GeneratedAddress = {"container": statusDesktop_mainWindow_overlay_popup2, "type": "Rectangle", "visible": True}
address_0x_StatusBaseText = {"container": statusDesktop_mainWindow_overlay_popup2, "text": RegularExpression("0x*"), "type": "StatusBaseText", "unnamed": 1, "visible": True}
addAccountPopup_GeneratedAddressesListPageIndicatior_StatusPageIndicator = {"container": statusDesktop_mainWindow_overlay_popup2, "objectName": "AddAccountPopup-GeneratedAddressesListPageIndicatior", "type": "StatusPageIndicator", "visible": True}
page_StatusBaseButton = {"checkable": False, "container": addAccountPopup_GeneratedAddressesListPageIndicatior_StatusPageIndicator, "objectName": RegularExpression("Page-*"), "type": "StatusBaseButton", "visible": True}

navBarListView_Wallet_navbar_PrimaryNavSidebarButton = {"checkable": True, "container": mainWindow_navBarListView_ListView, "objectName": "Wallet-navbar", "type": "PrimaryNavSidebarButton", "visible": True}
wallet_navbar_wallet_icon_StatusIcon = {"container": navBarListView_Wallet_navbar_PrimaryNavSidebarButton, "objectName": "wallet-icon", "type": "StatusIcon", "visible": True}

mainWallet_Address_Panel = {"container": statusDesktop_mainWindow, "objectName": "addressPanel", "type": "StatusAddressPanel", "visible": True}
mainWallet_Add_Account_Button = {"container": statusDesktop_mainWindow, "objectName": "addAccountButton", "type": "StatusRoundButton", "visible": True}
signPhrase_Ok_Button = {"container": statusDesktop_mainWindow, "type": "StatusFlatButton", "objectName": "signPhraseModalOkButton", "visible": True}
mainWallet_Network_Selector_Button = {"container": statusDesktop_mainWindow, "objectName": "networkSelectorButton", "type": "StatusListItem"}
mainWallet_Right_Side_Tab_Bar = {"container": statusDesktop_mainWindow, "objectName": "rightSideWalletTabBar", "type": "StatusTabBar"}
mainWallet_Ephemeral_Notification_List = {"container": statusDesktop_mainWindow, "objectName": "ephemeralNotificationList", "type": "StatusListView"}

# Assets view:
mainWallet_Assets_View_List = {"container": statusDesktop_mainWindow, "objectName": "assetViewStatusListView", "type": "StatusListView"}

# Network selector popup
mainWallet_Network_Popup_Chain_Repeater_1 = {"container": statusDesktop_mainWindow, "objectName": "networkSelectPopupChainRepeaterLayer1", "type": "Repeater"}

# Send popup:
mainWallet_totalCurrencyBalance = {"container": statusDesktop_mainWindow, "objectName": "walletLeftListAmountValue", "type": "StyledTextEdit"}
mainWallet_Footer_Send_Button = {"container": statusDesktop_mainWindow, "objectName": "walletFooterSendButton", "type": "StatusFlatButton"}
mainWallet_Send_Popup_Main = {"container": statusDesktop_mainWindow, "objectName": "sendModalScroll", "type": "StatusScrollView"}
mainWallet_Send_Popup_Amount_Input = {"container": statusDesktop_mainWindow, "objectName": "amountInput", "type": "TextEdit"}
mainWallet_Send_Popup_My_Accounts_Tab = {"container": statusDesktop_mainWindow, "objectName": "myAccountsTab", "type": "StatusTabButton"}
mainWallet_Send_Popup_My_Accounts_List = {"container": statusDesktop_mainWindow, "objectName": "myAccountsList", "type": "StatusListView"}
mainWallet_Send_Popup_Header_Accounts = {"container": statusDesktop_mainWindow, "objectName": "accountsListFloatingHeader", "type": "Repeater"}
mainWallet_Send_Popup_Networks_List = {"container": statusDesktop_mainWindow, "objectName": "networksList", "type": "Repeater"}
mainWallet_Send_Popup_Send_Button = {"container": statusDesktop_mainWindow, "objectName": "transactionModalFooterButton", "type": "StatusButton"}
mainWallet_Send_Popup_Asset_Selector = {"container": statusDesktop_mainWindow, "objectName": "assetSelectorButton", "type": "StatusComboBox"}
mainWallet_Send_Popup_Asset_List = {"container": statusDesktop_mainWindow, "objectName": "assetSelectorList", "type": "StatusListView"}
mainWallet_Send_Popup_GasPrice_Input = {"container": statusDesktop_mainWindow, "objectName": "gasPriceSelectorInput", "type": "StatusTextField"}

# Add/Edit account popup:
grid_Grid = {"container": statusDesktop_mainWindow_overlay, "id": "grid", "type": "Grid", "unnamed": 1, "visible": True}
color_StatusColorRadioButton = {"checkable": True, "container": statusDesktop_mainWindow_overlay, "type": "StatusColorRadioButton", "unnamed": 1, "visible": True}


mainWallet_AddEditAccountPopup_Content = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-Content", "type": "Item", "visible": True}
mainWallet_AddEditAccountPopup_PrimaryButton = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-PrimaryButton", "type": "StatusButton", "visible": True}
mainWallet_AddEditAccountPopup_BackButton = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-BackButton", "type": "StatusBackButton", "visible": True}
mainWallet_AddEditAccountPopup_AccountNameComponent = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-AccountName", "type": "StatusInput", "visible": True}
mainWallet_AddEditAccountPopup_AccountName = {"container": mainWallet_AddEditAccountPopup_AccountNameComponent, "type": "TextEdit", "unnamed": 1, "visible": True}
mainWallet_AddEditAccountPopup_AccountColorComponent = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-AccountColor", "type": "StatusColorSelectorGrid", "visible": True}
mainWallet_AddEditAccountPopup_AccountColorSelector = {"container": mainWallet_AddEditAccountPopup_AccountColorComponent, "type": "Repeater", "objectName": "statusColorRepeater", "visible": True, "enabled": True}
mainWallet_AddEditAccountPopup_AccountEmojiPopupButton = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-AccountEmoji", "type": "StatusFlatRoundButton", "visible": True}
mainWallet_AddEditAccountPopup_SelectedOrigin = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-SelectedOrigin", "type": "StatusListItem", "visible": True}
mainWallet_AddEditAccountPopup_OriginOption_Placeholder = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-OriginOption-%NAME%", "type": "StatusListItem", "visible": True}
mainWallet_AddEditAccountPopup_OriginOptionNewMasterKey = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-OriginOption-LABEL-OPTION-ADD-NEW-MASTER-KEY", "type": "StatusListItem", "visible": True}
addAccountPopup_OriginOption_StatusListItem = {"container": statusDesktop_mainWindow_overlay, "type": "StatusListItem", "visible": True}


mainWallet_AddEditAccountPopup_OriginOptionWatchOnlyAcc = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-OriginOption-LABEL-OPTION-ADD-WATCH-ONLY-ACC", "type": "StatusListItem", "visible": True}
mainWallet_AddEditAccountPopup_AccountWatchOnlyAddressComponent = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-WatchOnlyAddress", "type": "StatusInput", "visible": True}
mainWallet_AddEditAccountPopup_AccountWatchOnlyAddress = {"container": mainWallet_AddEditAccountPopup_AccountWatchOnlyAddressComponent, "type": "TextEdit", "unnamed": 1, "visible": True}
mainWallet_AddEditAccountPopup_EditDerivationPathButton = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-EditDerivationPath", "type": "StatusButton", "visible": True}
mainWallet_AddEditAccountPopup_ResetDerivationPathButton = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-ResetDerivationPath", "type": "StatusLinkText", "enabled": True, "visible": True}
mainWallet_AddEditAccountPopup_DerivationPathInputComponent = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-DerivationPathInput", "type": "DerivationPathInput", "visible": True}
mainWallet_AddEditAccountPopup_DerivationPathInput = {"container": mainWallet_AddEditAccountPopup_DerivationPathInputComponent, "type": "TextEdit", "unnamed": 1, "visible": True}
mainWallet_AddEditAccountPopup_PreDefinedDerivationPathsButton = {"container": mainWallet_AddEditAccountPopup_DerivationPathInputComponent, "objectName": "chevron-down-icon", "type": "StatusIcon", "visible": True}
mainWallet_AddEditAccountPopup_PreDefinedPathsOptionTestnetRopsten = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-PreDefinedDerivationPath-Ethereum Testnet (Ropsten)", "type": "StatusListItem", "visible": True}
mainWallet_AddEditAccountPopup_GeneratedAddressComponent = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-GeneratedAddress", "type": "StatusListItem", "visible": True}
mainWallet_AddEditAccountPopup_GeneratedAddress_99 = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-GeneratedAddress-99", "type": "Rectangle", "visible": True}
mainWallet_AddEditAccountPopup_PageIndicatorComponent = {"container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-GeneratedAddressesListPageIndicatior", "occurrence": 5, "type": "Rectangle", "visible": True}
mainWallet_AddEditAccountPopup_PageIndicatorPage_20 = {"container": statusDesktop_mainWindow, "objectName": "Page-20", "type": "StatusBaseButton", "visible": True}
mainWallet_AddEditAccountPopup_NonEthDerivationPathCheckBox = {"checkable": True, "container": statusDesktop_mainWindow, "objectName": "AddAccountPopup-ConfirmAddingNonEthDerivationPath", "type": "StatusCheckBox", "visible": True}
mainWallet_AddEditAccountPopup_MasterKey_ImportPrivateKeyOption = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-ImportPrivateKey", "type": "StatusListItem", "visible": True}
mainWallet_AddEditAccountPopup_MasterKey_ImportSeedPhraseOption = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-ImportUsingSeedPhrase", "type": "StatusListItem", "visible": True}
mainWallet_AddEditAccountPopup_MasterKey_GenerateSeedPhraseOption = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-GenerateNewMasterKey", "type": "StatusListItem", "visible": True}
mainWallet_AddEditAccountPopup_MasterKey_GoToKeycardSettingsOption = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-GoToKeycardSettings", "type": "StatusButton", "visible": True}
mainWallet_AddEditAccountPopup_PrivateKey = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-PrivateKeyInput", "type": "StatusPasswordInput", "visible": True}
mainWallet_AddEditAccountPopup_PrivateKeyNameComponent = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-PrivateKeyName", "type": "StatusInput", "visible": True}
mainWallet_AddEditAccountPopup_PrivateKeyName = {"container": mainWallet_AddEditAccountPopup_PrivateKeyNameComponent, "type": "TextEdit", "unnamed": 1, "visible": True}
mainWallet_AddEditAccountPopup_ImportedSeedPhraseKeyNameComponent = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-ImportedSeedPhraseKeyName", "type": "StatusInput", "visible": True}
mainWallet_AddEditAccountPopup_ImportedSeedPhraseKeyName = {"container": mainWallet_AddEditAccountPopup_ImportedSeedPhraseKeyNameComponent, "type": "TextEdit", "unnamed": 1, "visible": True}
mainWallet_AddEditAccountPopup_GeneratedSeedPhraseKeyNameComponent = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-GeneratedSeedPhraseKeyName", "type": "StatusInput", "visible": True}
mainWallet_AddEditAccountPopup_GeneratedSeedPhraseKeyName = {"container": mainWallet_AddEditAccountPopup_GeneratedSeedPhraseKeyNameComponent, "type": "TextEdit", "unnamed": 1, "visible": True}
mainWallet_AddEditAccountPopup_HavePenAndPaperCheckBox = {"checkable": True, "container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-HavePenAndPaper", "type": "StatusCheckBox", "visible": True}
mainWallet_AddEditAccountPopup_SeedPhraseWrittenCheckBox = {"checkable": True, "container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-SeedPhraseWritten", "type": "StatusCheckBox", "visible": True}
mainWallet_AddEditAccountPopup_StoringSeedPhraseConfirmedCheckBox = {"checkable": True, "container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-StoringSeedPhraseConfirmed", "type": "StatusCheckBox", "visible": True}
mainWallet_AddEditAccountPopup_SeedBackupAknowledgeCheckBox = {"checkable": True, "container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-SeedBackupAknowledge", "type": "StatusCheckBox", "visible": True}
mainWallet_AddEditAccountPopup_RevealSeedPhraseButton = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-RevealSeedPhrase", "type": "StatusButton", "visible": True}
mainWallet_AddEditAccountPopup_SeedPhraseWordAtIndex_Placeholder = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "SeedPhraseWordAtIndex-%WORD-INDEX%", "type": "StatusSeedPhraseInput", "visible": True}
mainWallet_AddEditAccountPopup_EnterSeedPhraseWordComponent = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "AddAccountPopup-EnterSeedPhraseWord", "type": "StatusInput", "visible": True}
mainWallet_AddEditAccountPopup_EnterSeedPhraseWord = {"container": mainWallet_AddEditAccountPopup_EnterSeedPhraseWordComponent, "type": "TextEdit", "unnamed": 1, "visible": True}
confirmSeedPhrasePanel_StatusSeedPhraseInput = {"container": statusDesktop_mainWindow, "type": "StatusSeedPhraseInput", "visible": True}
mainWallet_AddEditAccountPopup_SPWord = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": RegularExpression("enterSeedPhraseInputField*")}
mainWallet_AddEditAccountPopup_12WordsButton = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "12SeedButton", "type": "StatusSwitchTabButton"}
mainWallet_AddEditAccountPopup_18WordsButton = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "18SeedButton", "type": "StatusSwitchTabButton"}
mainWallet_AddEditAccountPopup_24WordsButton = {"container": mainWallet_AddEditAccountPopup_Content, "objectName": "24SeedButton", "type": "StatusSwitchTabButton"}
mainWallet_AddEditAccountPopup_SPWord_1 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField1"}
mainWallet_AddEditAccountPopup_SPWord_2 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField2"}
mainWallet_AddEditAccountPopup_SPWord_3 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField3"}
mainWallet_AddEditAccountPopup_SPWord_4 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField4"}
mainWallet_AddEditAccountPopup_SPWord_5 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField5"}
mainWallet_AddEditAccountPopup_SPWord_6 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField6"}
mainWallet_AddEditAccountPopup_SPWord_7 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField7"}
mainWallet_AddEditAccountPopup_SPWord_8 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField8"}
mainWallet_AddEditAccountPopup_SPWord_9 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField9"}
mainWallet_AddEditAccountPopup_SPWord_10 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField10"}
mainWallet_AddEditAccountPopup_SPWord_11 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField11"}
mainWallet_AddEditAccountPopup_SPWord_12 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField12"}
mainWallet_AddEditAccountPopup_SPWord_13 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField13"}
mainWallet_AddEditAccountPopup_SPWord_14 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField14"}
mainWallet_AddEditAccountPopup_SPWord_15 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField15"}
mainWallet_AddEditAccountPopup_SPWord_16 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField16"}
mainWallet_AddEditAccountPopup_SPWord_17 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField17"}
mainWallet_AddEditAccountPopup_SPWord_18 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField18"}
mainWallet_AddEditAccountPopup_SPWord_19 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField19"}
mainWallet_AddEditAccountPopup_SPWord_20 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField20"}
mainWallet_AddEditAccountPopup_SPWord_21 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField21"}
mainWallet_AddEditAccountPopup_SPWord_22 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField22"}
mainWallet_AddEditAccountPopup_SPWord_23 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField23"}
mainWallet_AddEditAccountPopup_SPWord_24 = {"container": mainWallet_AddEditAccountPopup_Content, "type": "TextEdit", "objectName": "enterSeedPhraseInputField24"}

# Remove account popup:
mainWallet_Remove_Account_Popup_Account_Notification = {"container": statusDesktop_mainWindow, "objectName": "RemoveAccountPopup-Notification", "type": "StatusBaseText", "visible": True}
mainWallet_Remove_Account_Popup_Account_Path_Component = {"container": statusDesktop_mainWindow, "objectName": "RemoveAccountPopup-DerivationPath", "type": "StatusInput", "visible": True}
mainWallet_Remove_Account_Popup_Account_Path = {"container": mainWallet_Remove_Account_Popup_Account_Path_Component, "type": "TextEdit", "unnamed": 1, "visible": True}
mainWallet_Remove_Account_Popup_HavePenPaperCheckBox = {"checkable": True, "container": statusDesktop_mainWindow, "objectName": "RemoveAccountPopup-HavePenPaper", "type": "StatusCheckBox", "visible": True}
mainWallet_Remove_Account_Popup_ConfirmButton = {"container": statusDesktop_mainWindow, "objectName": "RemoveAccountPopup-ConfirmButton", "type": "StatusButton", "visible": True}
mainWallet_Remove_Account_Popup_CancelButton = {"container": statusDesktop_mainWindow, "objectName": "RemoveAccountPopup-CancelButton", "type": "StatusFlatButton", "visible": True}

# saved address add popup
mainWallet_Saved_Addreses_Popup_Name_Input = {"container": statusDesktop_mainWindow, "objectName": "savedAddressNameInput", "type": "TextEdit"}
mainWallet_Saved_Addreses_Popup_Address_Input = {"container": statusDesktop_mainWindow, "objectName": "savedAddressAddressInput", "type": "StatusInput"}
mainWallet_Saved_Addreses_Popup_Address_Input_Edit = {"container": statusDesktop_mainWindow, "objectName": "savedAddressAddressInputEdit", "type": "TextEdit"}
mainWallet_Saved_Addreses_Popup_Address_Add_Button = {"container": statusDesktop_mainWindow, "objectName": "addSavedAddress", "type": "StatusButton"}
mainWallet_Saved_Addreses_Popup_Add_Network_Selector = {"container": statusDesktop_mainWindow, "objectName": "addSavedAddressNetworkSelector", "type": "StatusNetworkSelector", "visible": True}
mainWallet_Saved_Addreses_Popup_Add_Network_Button = {"container": statusDesktop_mainWindow_overlay, "objectName": "addNetworkTagItemButton", "type": "StatusRoundButton", "visible": True}
mainWallet_Saved_Addreses_Popup_Add_Network_Selector_Tag = {"container": statusDesktop_mainWindow_overlay, "objectName": "networkSelectorTag", "type": "StatusNetworkListItemTag"}
mainWallet_Saved_Addresses_Popup_Add_Network_Selector_Mainnet_checkbox = {"container": statusDesktop_mainWindow_overlay, "objectName": "networkSelectionCheckbox_Mainnet", "type": "StatusCheckBox", "visible": True}
mainWallet_Saved_Addresses_Popup_Add_Network_Selector_Optimism_checkbox = {"container": statusDesktop_mainWindow_overlay, "objectName": "networkSelectionCheckbox_Optimism", "type": "StatusCheckBox", "visible": True}
mainWallet_Saved_Addresses_Popup_Add_Network_Selector_Arbitrum_checkbox = {"container": statusDesktop_mainWindow_overlay, "objectName": "networkSelectionCheckbox_Arbitrum", "type": "StatusCheckBox", "visible": True}
mainWallet_Saved_Addresses_Popup_Network_Selector_Mainnet_network_tag = {"container": statusDesktop_mainWindow_overlay, "objectName": "networkTagRectangle_eth", "type": "Rectangle", "visible": True}
mainWallet_Saved_Addresses_Popup_Network_Selector_Optimism_network_tag = {"container": statusDesktop_mainWindow_overlay, "objectName": "networkTagRectangle_opt", "type": "Rectangle", "visible": True}
mainWallet_Saved_Addresses_Popup_Network_Selector_Arbitrum_network_tag = {"container": statusDesktop_mainWindow_overlay, "objectName": "networkTagRectangle_arb", "type": "Rectangle", "visible": True}
# Collectibles view
mainWallet_Collections_Repeater = {"container": statusDesktop_mainWindow, "objectName": "collectionsRepeater", "type": "Repeater"}
mainWallet_Collectibles_Repeater = {"container": statusDesktop_mainWindow, "objectName": "collectiblesRepeater", "type": "Repeater"}

# Shared Popup
sharedPopup_Popup_Content = {"container": statusDesktop_mainWindow, "objectName": "KeycardSharedPopupContent", "type": "Item"}
sharedPopup_Password_Input = {"container": sharedPopup_Popup_Content, "objectName": "keycardPasswordInput", "type": "TextField"}
sharedPopup_Primary_Button = {"container": statusDesktop_mainWindow, "objectName": "PrimaryButton", "type": "StatusButton", "visible": True, "enabled": True}
sharedPopup_Cancel_Button = {"container": statusDesktop_mainWindow_overlay, "type": "StatusButton", "id": "cancelButton", "visible": True}

# Transactions view
mainWallet_Transactions_List = {"container": statusDesktop_mainWindow, "objectName": "walletAccountTransactionList", "type": "StatusListView"}
mainWallet_Transactions_Detail_View_Header = {"container": statusDesktop_mainWindow, "objectName": "transactionDetailHeader", "type": "TransactionDelegate"}
