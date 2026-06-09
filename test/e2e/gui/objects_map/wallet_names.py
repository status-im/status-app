from objectmaphelper import *
from gui.objects_map.names import statusDesktop_mainWindow, statusDesktop_mainWindow_overlay

mainWindow_WalletLayout = {"container": statusDesktop_mainWindow, "objectName": "walletLayoutReal", "type": "WalletLayout", "visible": True}

# Left Wallet Panel
mainWallet_LeftTab = {"container": mainWindow_WalletLayout, "objectName": "walletLeftTab", "type": "LeftTabView", "visible": True}

mainWallet_Saved_Addresses_Button = { "container": mainWallet_LeftTab, "objectName": "savedAddressesBtn", "type": "StatusFlatButton", "visible": True}
walletAccounts_StatusListView = {"container": mainWallet_LeftTab, "objectName": "walletAccountsListView", "type": "StatusListView", "visible": True}
mainWallet_All_Accounts_Button = {"container": walletAccounts_StatusListView, "objectName": "allAccountsBtn", "type": "StatusFlatButton", "visible": True}
mainWallet_Add_Account_Button = {"container": mainWallet_LeftTab, "objectName": "addAccountButton", "type": "StatusRoundButton", "visible": True}
walletAccount_StatusListItem = {"container": walletAccounts_StatusListView, "objectName": "walletAccountListItem", "type": "StatusListItem", "visible": True}
mainWallet_All_Accounts_Balance = {"container": mainWallet_All_Accounts_Button, "objectName": "walletLeftListAmountValue", "type": "StatusTextWithLoadingState", "visible": True}

# Saved Address View
mainWindow_SavedAddressesView = {"container": statusDesktop_mainWindow, "type": "SavedAddressesView", "unnamed": 1, "visible": True}
mainWindow_SavedAddressesView_2 = {"container": mainWindow_WalletLayout, "type": "SavedAddressesView", "unnamed": 1, "visible": True}
mainWallet_Saved_Addresses_Add_Buttton = {"container": mainWindow_SavedAddressesView, "objectName": "walletHeaderButton", "type": "StatusButton"}
mainWallet_Saved_Addresses_List = {"container": mainWindow_SavedAddressesView, "objectName": "SavedAddressesView_savedAddresses", "type": "StatusListView"}
savedAddressView_Delegate = {"container": mainWallet_Saved_Addresses_List, "objectName": RegularExpression("savedAddressView_Delegate*"), "type": "SavedAddressesDelegate", "visible": True}
send_StatusRoundButton = {"container": "", "type": "StatusRoundButton", "unnamed": 1, "visible": True}
savedAddressView_Delegate_menuButton = {"container": mainWindow_SavedAddressesView, "objectName": RegularExpression("savedAddressView_Delegate_menuButton*"), "type": "StatusRoundButton", "visible": True}
savedAddressesArea_SavedAddresses = {"container": mainWindow_SavedAddressesView, "objectName": "savedAddressesArea", "type": "SavedAddresses", "visible": True}
savedAddresses_area = {"container": mainWindow_SavedAddressesView_2, "objectName": "savedAddressesArea", "type": "SavedAddresses", "visible": True}

# Wallet Account View
mainWindow_RightTabView = {"container": statusDesktop_mainWindow, "type": "RightTabView", "unnamed": 1, "visible": True}
mainWallet_Account_Name = {"container": mainWindow_RightTabView, "objectName": "walletHeaderTitle", "type": "StatusBaseText", "visible": True}
mainWindow_Send_Button = {"container": statusDesktop_mainWindow, "objectName": "walletFooterSendButton", "type": "StatusFlatButton", "visible": True}
mainWindow_Receive_Button = {"checkable": False, "container": statusDesktop_mainWindow, "objectName": "walletFooterReceiveButton", "type": "StatusFlatButton", "visible": True}
mainWindow_Bridge_Button = {"checkable": False, "container": statusDesktop_mainWindow, "objectName": "walletFooterBridgeButton", "type": "StatusFlatButton", "visible": True}
mainWindow_Swap_Button = {"checkable": False, "container": statusDesktop_mainWindow, "objectName": "walletFooterSwapButton", "type": "StatusFlatButton", "visible": True}

mainWindow_RightTabView = {"container": statusDesktop_mainWindow, "type": "RightTabView", "unnamed": 1, "visible": True}
filterButton_StatusFlatButton = {"checkable": True, "container": mainWindow_RightTabView, "objectName": "filterButton", "type": "StatusFlatButton", "visible": True}
cmbTokenOrder_SortOrderComboBox = {"container": mainWindow_RightTabView, "objectName": "cmbTokenOrder", "type": "SortOrderComboBox", "visible": True}
collectibles_cmbTokenOrder_SortOrderComboBox = {"container": mainWindow_RightTabView, "id": "cmbTokenOrder", "type": "SortOrderComboBox", "unnamed": 1, "visible": True}
rightSideWalletTabBar_StatusTabBar = {"container": mainWindow_RightTabView, "objectName": "rightSideWalletTabBar", "type": "StatusTabBar", "visible": True}
rightSideWalletTabBar_Assets_StatusTabButton = {"checkable": True, "container": rightSideWalletTabBar_StatusTabBar, "objectName": "assetsTabButton", "text": "Assets", "type": "StatusTabButton", "visible": True}
rightSideWalletTabBar_Collectibles_StatusTabButton = {"checkable": True, "container": rightSideWalletTabBar_StatusTabBar, "objectName": "collectiblesTabButton", "text": "Collectibles", "type": "StatusTabButton", "visible": True}
rightSideWalletTabBar_Activity_StatusTabButton = {"checkable": True, "container": rightSideWalletTabBar_StatusTabBar, "objectName": "activityTabButton", "text": "Activity", "type": "StatusTabButton", "visible": True}

"""Wallet assets view"""
assets_view = {"container": mainWindow_RightTabView, "objectName": "assetViewStatusListView", "type": "StatusListView", "visible": True}
assets_viewTokenItem = {"container": mainWindow_RightTabView, "objectName": RegularExpression("AssetView_TokenListItem_*"), "type": "TokenDelegate", "visible": True}
asset_details_view = {"container": mainWindow_RightTabView, "id": "assetDetailView", "type": "AssetsDetailView", "unnamed": 1, "visible": True}
asset_details_header = {"container": mainWindow_RightTabView, "id": "tokenDetailsHeader", "type": "AssetsDetailsHeader", "unnamed": 1, "visible": True}
asset_details_tool_bar = {"container": statusDesktop_mainWindow, "objectName": "statusToolBar", "type": "StatusToolBar", "visible": True}
asset_details_back_button = {"container": asset_details_tool_bar, "objectName": "toolBarBackButton", "type": "StatusFlatButton", "visible": True}
asset_details_chart_panel = {"container": asset_details_view, "type": "StatusChartPanel", "visible": True}
asset_details_chart_canvas = {"container": asset_details_view, "type": "ChartCanvas", "visible": True}
itemDelegate = {"checkable": False, "container": statusDesktop_mainWindow_overlay, "id": "menuDelegate", "type": "ItemDelegate", "unnamed": 1, "visible": True}
arrow_icon_StatusIcon = {"container": statusDesktop_mainWindow_overlay, "objectName": "arrow-up-icon", "type": "StatusIcon", "visible": True}
collectible_item = {"container": mainWindow_RightTabView, "type": "CollectibleView", "unnamed": 1, "visible": True}
mainWindow_settingsContentBaseScrollView_StatusScrollView_general = {"container":  statusDesktop_mainWindow, "objectName": "settingsContentBaseScrollView", "type": "StatusScrollView", "visible": True}
settingsContentBaseScrollView_manageTokensDelegate_ManageTokensDelegate = {"container": mainWindow_settingsContentBaseScrollView_StatusScrollView_general, "objectName": RegularExpression("manageTokensDelegate-*"), "type": "ManageTokensDelegate", "visible": True}
tabBar_Assets_StatusTabButton = {"checkable": True, "container": mainWindow_settingsContentBaseScrollView_StatusScrollView_general, "objectName": "assetsButton", "type": "StatusTabButton", "unnamed": 1, "visible": True}

mainWindow_Save_and_apply_StatusButton = {"checkable": False, "container": statusDesktop_mainWindow, "objectName": "settingsDirtyToastMessageSaveButton", "text": "Save and apply", "type": "StatusButton", "visible": True}
mainWindow_Save_StatusFlatButton = {"checkable": False, "container": statusDesktop_mainWindow, "id": "saveForLaterButton", "text": "Save", "type": "StatusFlatButton", "unnamed": 1, "visible": True}

"""Wallet account context menu"""

walletAccountContextMenu = {"container": statusDesktop_mainWindow_overlay, "objectName": "AccountContextMenu", "type": "PopupItem", "visible": True}
contextMenuItem_Delete = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": RegularExpression("AccountMenu-DeleteAction*"), "type": "StatusMenuItem", "visible": True}
contextMenuItem_Edit = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": RegularExpression("AccountMenu-EditAction*"), "type": "StatusMenuItem", "visible": True}
contextMenuItem_Copy_Address = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": RegularExpression("AccountMenu-CopyAddressAction*"), "type": "StatusSuccessAction", "visible": True}
contextMenuItem_HideInclude = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": RegularExpression("AccountMenu-HideFromTotalBalance*"), "type": "StatusMenuItem", "visible": True}
addWatchedAddress = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": RegularExpression("AccountMenu-AddWatchOnlyAccountAction*"), "type": "StatusMenuItem", "visible": True}
addNewAccount = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": RegularExpression("AccountMenu-AddNewAccountAction*"), "type": "StatusMenuItem", "visible": True}

"""Receive modal"""
receiveModal = {"container": statusDesktop_mainWindow_overlay, "objectName": "ReceiveModal", "type": "PopupItem", "visible": True}
textContent_StatusBaseText = {"container": statusDesktop_mainWindow_overlay, "objectName": "textContent", "type": "StatusBaseText", "visible": True}
greenCircleAroundIcon_Rectangle = {"container": statusDesktop_mainWindow_overlay, "id": "greenCircleAroundIcon", "type": "Rectangle", "unnamed": 1, "visible": True}
qrCodeImage_Image = {"container": statusDesktop_mainWindow_overlay, "objectName": "qrCodeImage", "type": "Image", "visible": True}

"""Remove saved address popup"""
removeSavedAddressPopup = {"container": statusDesktop_mainWindow_overlay, "objectName": "RemoveSavedAddressPopup", "type": "PopupItem", "visible": True}
removeSavedAddressButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "RemoveSavedAddressPopup-ConfirmButton", "type": "StatusButton", "visible": True}
cancelRemovalButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "RemoveSavedAddressPopup-CancelButton", "type": "StatusFlatButton", "visible": True}
