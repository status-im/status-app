from objectmaphelper import *
from gui.objects_map.names import statusDesktop_mainWindow, statusDesktop_mainWindow_overlay

mainWindow_ProfileLayout = {"container": statusDesktop_mainWindow, "objectName": "profileStatusSectionLayout", "type": "ProfileLayout", "visible": True}
mainWindow_StatusSectionLayout_ContentItem = {"container": mainWindow_ProfileLayout, "objectName": "StatusSectionLayout", "type": "ContentItem", "visible": True}
settingsContentBase_ScrollView = {"container": statusDesktop_mainWindow, "objectName": "settingsContentBaseScrollView", "type": "StatusScrollView", "visible": True}
settingsContentBaseScrollView_Flickable = {"container": settingsContentBase_ScrollView, "type": "Flickable", "unnamed": 1, "visible": True}

# Left Panel

mainWindow_LeftTabView = {"container": statusDesktop_mainWindow, "id": "leftPanel", "type": "SettingsLeftTabView", "unnamed": 1, "visible": True}
LeftTabView_ScrollView = {"container": mainWindow_LeftTabView, "type": "StatusScrollView", "unnamed": 1, "visible": True}
LeftTabProfileMenu = {"container": LeftTabView_ScrollView, "objectName": "leftTabViewProfileMenu", "type": "MenuPanel", "visible": True}

mainWindow_Settings_StatusNavigationPanelHeadline = {"container": mainWindow_LeftTabView, "type": "StatusNavigationPanelHeadline", "unnamed": 1, "visible": True}
mainWindow_scrollView_StatusScrollView = {"container": mainWindow_LeftTabView, "id": "scrollView", "type": "StatusScrollView", "unnamed": 1, "visible": True}
mainWindow_settingsList_SettingsList = {"container": statusDesktop_mainWindow, "id": "settingsList", "type": "SettingsList", "unnamed": 1, "visible": True}
mainWindow_settingsList_SettingsListItem = {"container": mainWindow_settingsList_SettingsList, "type": "StatusNavigationListItem", "visible": True}
mainWindow_settingsList_VerticalScroll = {"container": mainWindow_settingsList_SettingsList, "id": "verticalScrollBar", "type": "StatusScrollBar", "unnamed": 1, "visible": True}
scrollView_MenuItem_StatusNavigationListItem = {"container": mainWindow_scrollView_StatusScrollView, "type": "StatusNavigationListItem", "visible": True}


scrollView_Flickable = {"container": mainWindow_scrollView_StatusScrollView, "type": "Flickable", "unnamed": 1, "visible": True}
settingsBackUpSeedPhraseOption = {"container": mainWindow_scrollView_StatusScrollView, "objectName": "19-MainMenuItem", "type": "StatusNavigationListItem", "visible": True}
settingsWalletOption = {"container": mainWindow_settingsList_SettingsList, "objectName": "5-MenuItem", "type": "StatusNavigationListItem", "visible": True}
settingsSignOutQuitOption = {"container": LeftTabProfileMenu, "objectName": "17-ExtraMenuItem", "type": "StatusNavigationListItem", "visible": True}

# Communities View
mainWindow_CommunitiesView = {"container": statusDesktop_mainWindow, "id": "communitiesView", "type": "Loader", "unnamed": 1}
mainWindow_settingsContentBaseScrollView_StatusScrollView = {"container": mainWindow_CommunitiesView, "objectName": "settingsContentBaseScrollView", "type": "StatusScrollView", "visible": True}
settingsContentBaseScrollView_listItem_StatusListItem = {"container": mainWindow_settingsContentBaseScrollView_StatusScrollView, "id": "listItem", "type": "StatusListItem", "unnamed": 1, "visible": True}

# Templates to generate Real Name in test
settings_iconOrImage_StatusSmartIdenticon = {"id": "iconOrImage", "type": "StatusSmartIdenticon", "unnamed": 1, "visible": True}
settings_StatusTextWithLoadingState = {"type": "StatusTextWithLoadingState", "unnamed": 1, "visible": True}
settings_statusListItemSubTitle = {"objectName": "statusListItemSubTitle", "type": "StatusTextWithLoadingState", "visible": True}
settings_StatusFlatButton = {"type": "StatusFlatButton", "unnamed": 1, "visible": True}

# Messaging View
mainWindow_MessagingView = {"container": statusDesktop_mainWindow, "type": "MessagingView", "unnamed": 1, "visible": True}
allowNewContactRequestsSection = {"container": statusDesktop_mainWindow, "id": "allowNewContactRequest", "type": "StatusListItem", "unnamed": 1, "visible": True}
allowNewContactRequestsSectionToggle = {"checkable": True, "container": allowNewContactRequestsSection, "id": "switch3", "type": "StatusSwitch", "unnamed": 1, "visible": True}
contactsListItem_btn_StatusContactRequestsIndicatorListItem = {"container": statusDesktop_mainWindow, "objectName": "MessagingView_ContactsListItem_btn", "type": "StatusContactRequestsIndicatorListItem"}
settingsContentBase_ScrollView = {"container": statusDesktop_mainWindow, "objectName": "settingsContentBaseScrollView", "type": "StatusScrollView", "visible": True}
always_ask_radioButton_StatusRadioButton = {"container": settingsContentBase_ScrollView, "objectName": "MessagingView_AlwaysAsk_RadioButton", "type": "SettingsRadioButton", "visible": True}
always_show_radioButton_StatusRadioButton = {"container": settingsContentBase_ScrollView, "objectName": "MessagingView_AlwaysShow_RadioButton", "type": "SettingsRadioButton", "visible": True}
never_show_radioButton_StatusRadioButton = {"container": settingsContentBase_ScrollView, "objectName": "MessagingView_NeverShow_RadioButton", "type": "SettingsRadioButton", "visible": True}

# Contacts View
mainWindow_ContactsView = {"container": statusDesktop_mainWindow, "id": "contactsView", "type": "Loader", "unnamed": 1, "visible": True}
mainWindow_Send_contact_request_to_chat_key_StatusButton = {"checkable": False, "container": mainWindow_ContactsView, "objectName": "ContactsView_ContactRequest_Button", "type": "StatusButton", "visible": True}
contactsTabBar_Pending_Requests_StatusTabButton = {"container": mainWindow_ContactsView, "objectName": "ContactsView_PendingRequest_Button", "type": "StatusTabButton", "visible": True}
settingsContentBaseScrollView_ContactListPanel = {"container": settingsContentBase_ScrollView, "objectName": "ContactListPanel_ListView", "type": "ContactsListPanel", "visible": True}
contactRequestItemSettings = {"checkable": False, "container": settingsContentBaseScrollView_ContactListPanel, "type": "ContactPanel", "unnamed": 1, "visible": True}
settingsContentBaseScrollView_Item = {"container": mainWindow_ContactsView, "type": "Item", "unnamed": 1, "visible": True}
settingsContentBaseScrollView_sentRequests_ContactsListPanel = {"container": mainWindow_ContactsView, "objectName": "ContactListPanel", "type": "ContactsListPanel", "visible": True}
settingsContentBaseScrollView_ContactListPanel_Header = {"container": settingsContentBase_ScrollView, "type": "SectionComponent", "unnamed": 1, "visible": True}
mainWindow_contactsTabBar_StatusTabBar = {"container": statusDesktop_mainWindow, "id": "contactsTabBar", "type": "StatusTabBar", "unnamed": 1, "visible": True}
contactsTabBar_Contacts_StatusTabButton = {"checkable": True, "container": mainWindow_contactsTabBar_StatusTabBar, "objectName": "ContactsView_Contacts_Button", "type": "StatusTabButton", "visible": True}
settingsContentBaseScrollView_receivedRequests_ContactsListPanel = {"container": mainWindow_ContactsView, "objectName": "ContactsListPanel", "type": "ContactsListPanel", "visible": True}
settingsContentBaseScrollView_mutualContacts_ContactsListPanel = {"container": mainWindow_ContactsView, "id": "mutualContacts", "type": "ContactsListPanel", "unnamed": 1, "visible": True}
settingsContentBaseScrollView_NoFriendsRectangle = {"container": mainWindow_ContactsView, "type": "NoFriendsRectangle", "unnamed": 1, "visible": True}
settingsContentBaseScrollView_Invite_friends_StatusButton = {"container": mainWindow_ContactsView, "objectName": "inviteFriendsStatusButton", "type": "StatusButton", "visible": True}

view_Profile_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "viewProfile_StatusItem", "type": "StatusMenuItem", "visible": True}
verify_Identity_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "verifyIdentity_StatusItem", "type": "StatusMenuItem", "visible": True}
respond_to_ID_Request_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "pendingIdentity_StatusItem", "type": "StatusMenuItem", "visible": True}
settingsContentBaseScrollView_Respond_to_ID_Request_StatusFlatButton = {"container": mainWindow_ContactsView, "objectName": "verifyIdentity_StatusItem", "type": "StatusFlatButton", "unnamed": 1, "visible": True}
contactsTabBar_Blocked_StatusTabButton = {"container": mainWindow_ContactsView, "objectName": "ContactsView_Blocked_Button", "type": "StatusTabButton", "visible": True}
unblock_user_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "unblock_StatusItem", "type": "StatusMenuItem", "visible": True}
block_user_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "blockUser_StatusItem", "type": "StatusMenuItem", "visible": True}

# Keycard Settings View
mainWindow_KeycardView = {"container": statusDesktop_mainWindow, "type": "KeycardView", "unnamed": 1, "visible": True}
setupFromExistingKeycardAccount_StatusListItem = {"container": settingsContentBase_ScrollView, "objectName": "setupFromExistingKeycardAccount", "type": "StatusListItem", "visible": True}
createNewKeycardAccount_StatusListItem = {"container": settingsContentBase_ScrollView, "objectName": "createNewKeycardAccount", "type": "StatusListItem", "visible": True}
importRestoreKeycard_StatusListItem = {"container": settingsContentBase_ScrollView, "objectName": "importRestoreKeycard", "type": "StatusListItem", "visible": True}
importFromKeycard_StatusListItem = {"container": settingsContentBase_ScrollView, "objectName": "importFromKeycard", "type": "StatusListItem", "visible": True}
checkWhatsNewKeycard_StatusListItem = {"container": settingsContentBase_ScrollView, "objectName": "checkWhatsNewKeycard", "type": "StatusListItem", "visible": True}
factoryResetKeycard_StatusListItem = {"container": settingsContentBase_ScrollView, "objectName": "factoryResetKeycard", "type": "StatusListItem", "visible": True}

# Wallet Settings View
mainWindow_WalletView = {"container": statusDesktop_mainWindow, "id": "walletView", "type": "Loader", "unnamed": 1, "visible": True}
settingsWallet_View = {"container": statusDesktop_mainWindow, "type": "WalletView", "unnamed": 1, "visible": True}
settings_Wallet_MainView_Networks = {"container": statusDesktop_mainWindow, "objectName": "networksItem", "type": "StatusListItem"}
settings_Wallet_MainView_Manage_Tokens = {"container": settingsContentBase_ScrollView, "objectName": "manageTokensItem", "type": "StatusListItem", "visible": True}
settings_Wallet_MainView_AddNewAccountButton = {"container": statusDesktop_mainWindow, "objectName": "settings_Wallet_MainView_AddNewAccountButton", "type": "StatusButton", "visible": True}
settingsContentBaseScrollView_accountOrderItem_StatusListItem = {"container": settingsContentBase_ScrollView, "objectName": "accountOrderItem", "type": "StatusListItem", "visible": True}
settingsContentBaseScrollView_savedAddressesItem_StatusListItem = {"container": settingsContentBase_ScrollView, "objectName": "savedAddressesItem", "type": "StatusListItem", "visible": True}
settingsContentBaseScrollView_StatusListItem = {"container": settingsContentBase_ScrollView, "type": "StatusListItem", "unnamed": 1, "visible": True}
settings_Wallet_NetworksView_TestNet_Toggle = {"container": statusDesktop_mainWindow, "objectName": "testnetModeSwitch", "type": "StatusSwitch"}
settings_Wallet_NetworksView_TestNet_Toggle_Title = {"container": settingsContentBase_ScrollView, "objectName": "statusListItemSubTitle", "type": "StatusTextWithLoadingState", "visible": True}
settings_Wallet_SavedAddresses_AddAddressButton = {"container": statusDesktop_mainWindow, "objectName": "addNewSavedAddressButton", "type": "StatusButton", "visible": True}
settings_Wallet_SavedAddress_ItemDelegate ={"container": settingsContentBase_ScrollView, "objectName": RegularExpression("savedAddressView_Delegate*"), "type": "SavedAddressesDelegate", "visible": True}
savedAddressItemKebabButton = {"container": statusDesktop_mainWindow, "objectName": RegularExpression("savedAddressView_Delegate_menuButton*"), "type": "StatusRoundButton", "visible": True}
settingsContentBaseScrollView_Goerli_testnet_active_StatusBaseText = {"container": settingsContentBase_ScrollView, "type": "StatusBaseText", "unnamed": 1, "visible": True}
settingsContentBaseScrollView_accountsList_StatusListView = {"container": settingsContentBase_ScrollView, "id": "accountsList", "type": "StatusListView", "unnamed": 1, "visible": True}
settingsContentBaseScrollView_draggableDelegate_StatusDraggableListItem = {"checkable": False, "container": settingsContentBase_ScrollView, "id": "draggableDelegate", "type": "StatusDraggableListItem", "unnamed": 1, "visible": True}
settingsContentBaseScrollView_accountOrderView_AccountOrderView = {"container": settingsContentBase_ScrollView, "id": "accountOrderView", "type": "AccountOrderView", "unnamed": 1, "visible": True}
settingsContentBaseScrollView_StatusBaseText = {"container": settingsContentBase_ScrollView, "type": "StatusBaseText", "unnamed": 1, "visible": True}
mainWindow_StatusToolBar = {"container": statusDesktop_mainWindow, "objectName": "statusToolBar", "type": "StatusToolBar", "visible": True}
main_toolBar_back_button = {"container": mainWindow_StatusToolBar, "objectName": "toolBarBackButton", "type": "StatusFlatButton", "visible": True}
settingsContentBaseScrollView_WalletNetworkDelegate_template = {"container": settingsContentBase_ScrollView, "objectName": "walletNetworkDelegate_Mainnet_1", "type": "WalletNetworkDelegate", "visible": True}
networkItemEditTemplate = { "container": settingsContentBase_ScrollView, "objectName": RegularExpression("editNetwork_*"), "type": "StatusFlatButton", "visible": True}
networkItemToggle = {"checkable": True, "container": settingsContentBase_ScrollView, "objectName": RegularExpression("isActiveSwitch_*"), 'type': 'StatusSwitch', 'visible': True}

networkSettingsNetworks_Mainnet = {"container": settingsContentBase_ScrollView, "objectName": "walletNetworkDelegate_Mainnet_1", "type": "WalletNetworkDelegate", "visible": True}
networkSettingsNetworks_Mainnet_Goerli = {"container": settingsContentBase_ScrollView, "objectName": "walletNetworkDelegate_Mainnet_5", "type": "WalletNetworkDelegate", "visible": True}
networkSettingsNetworks_Optimism = {"container": settingsContentBase_ScrollView, "objectName": "walletNetworkDelegate_Optimism_10", "type": "WalletNetworkDelegate", "visible": True}
networkSettingsNetworks_Optimism_Goerli = {"container": settingsContentBase_ScrollView, "objectName": "walletNetworkDelegate_Optimism_420", "type": "WalletNetworkDelegate", "visible": True}
networkSettingsNetworks_Arbitrum = {"container": settingsContentBase_ScrollView, "objectName": "walletNetworkDelegate_Arbitrum_42161", "type": "WalletNetworkDelegate", "visible": True}
networkSettingsNetworks_Arbitrum_Goerli = {"container": settingsContentBase_ScrollView, "objectName": "walletNetworkDelegate_Arbitrum_421613", "type": "WalletNetworkDelegate", "visible": True}
networkSettingsNetworks_Mainnet_Goerli_sensor = {"container": networkSettingsNetworks_Mainnet_Goerli, "objectName": "walletNetworkDelegate_Mainnet_5_sensor", "id": "sensor", "type": "MouseArea", "unnamed": 1, "visible": True}
networkSettingsNetowrks_Mainnet_Testlabel = {"container": networkSettingsNetworks_Mainnet_Goerli_sensor, "objectName": "testnetLabel_Mainnet", "type": "StatusBaseText", "visible": True}
settingsWalletAccountDelegate_Status_account = {"container": settingsContentBase_ScrollView, "objectName": "Status account", "type": "WalletAccountDelegate", "visible": True}
settingsWalletAccountDelegate = {"container": settingsContentBase_ScrollView, "index": 0, "objectName": RegularExpression("*"), "type": "WalletAccountDelegate", "visible": True}
settingsWalletKeyPairDelegate = {"container": settingsContentBase_ScrollView, "objectName": "walletKeyPairDelegate", "type": "StatusListItem", "visible": True}
settingsWalletAccountTotalBalance = {"container": settingsContentBase_ScrollView, "objectName": "includeTotalBalanceListItem", "type": "StatusListItem", "visible": True}
settingsWalletAccountTotalBalanceToggle = {"checkable": True, "container": settingsWalletAccountTotalBalance, "type": "StatusSwitch", "visible": True}
settingsContentBaseScrollView_StatusFlatRoundButton = {"container": mainWindow_settingsContentBaseScrollView_StatusScrollView, "type": "StatusFlatRoundButton", "unnamed": 1, "visible": True}
rename_keypair_StatusMenuItem = {"checkable": False, "container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "renameKeypairMenuItem", "type": "StatusMenuItem", "visible": True}

# Wallet Account Details view
walletAccountViewEditAccountButton = {"container": statusDesktop_mainWindow, "objectName": "walletAccountViewEditAccountButton", "type": "StatusButton"}
walletAccountViewAccountName = {"container": statusDesktop_mainWindow, "objectName": "walletAccountViewAccountName", "type": "StatusBaseText"}
walletAccountViewAccountEmoji = {"container": statusDesktop_mainWindow, "objectName": "walletAccountViewAccountImage", "type": "StatusEmoji", "visible": True}
walletAccountViewRemoveAccountButton = {"container": statusDesktop_mainWindow, "objectName": "deleteAccountButton", "type": "StatusButton"}
walletAccountViewDetailsLabel = {"container": settingsContentBase_ScrollView, "objectName": "AccountDetails_TextLabel", "type": "StatusBaseText"}
walletAccountViewBalance = {"container": settingsContentBase_ScrollView, "objectName": "Balance_ListItem", "type": "WalletAccountDetailsListItem"}
walletAccountViewAddress = {"container": settingsContentBase_ScrollView, "objectName": "Address_ListItem", "type": "WalletAccountDetailsListItem"}
walletAccountViewKeypairItem = {"container": settingsContentBase_ScrollView, "objectName": "KeyPair_Item", "type": "WalletAccountDetailsKeypairItem"}
walletAccountViewOrigin = {"container": settingsContentBase_ScrollView, "objectName": "Origin_ListItem", "type": "WalletAccountDetailsListItem"}
walletAccountViewDerivationPath = {"container": settingsContentBase_ScrollView, "objectName": "DerivationPath_ListItem", "type": "WalletAccountDetailsListItem"}
walletAccountViewStored = {"container": settingsContentBase_ScrollView, "objectName": "Stored_ListItem", "type": "WalletAccountDetailsListItem"}
walletAccountViewPreferredNetworks = {"container": settingsContentBase_ScrollView, "objectName": "PreferredNetworks_ListItem", "type": "StatusListItem"}

# Wallet edit network view
settingsContentBaseScrollView_editPreviwTabBar_StatusTabBar = {"container": statusDesktop_mainWindow, "objectName": "editPreviwTabBar", "type": "StatusTabBar"}
editNetworkLiveButton = {"container": settingsContentBaseScrollView_editPreviwTabBar_StatusTabBar, "objectName": "editNetworkLiveButton", "type": "StatusTabButton"}
editNetworkTestButton = {"container": settingsContentBaseScrollView_editPreviwTabBar_StatusTabBar, "objectName": "editNetworkTestButton", "type": "StatusTabButton"}
editNetworkNameInput = {"container": statusDesktop_mainWindow, "objectName": "editNetworkNameInput", "type": "TextEdit"}
editNetworkShortNameInput = {"container": statusDesktop_mainWindow, "objectName": "editNetworkShortNameInput", "type": "TextEdit"}
editNetworkChainIdInput = {"container": statusDesktop_mainWindow, "objectName": "editNetworkChainIdInput", "type": "TextEdit"}
editNetworkSymbolInput = {"container": statusDesktop_mainWindow, "objectName": "editNetworkSymbolInput", "type": "TextEdit"}
editNetworkMainRpcInput = {"container": statusDesktop_mainWindow, "objectName": "editNetworkMainRpcInput", "type": "TextEdit", "visible": True}
editNetworkFailoverRpcUrlInput = {"container": statusDesktop_mainWindow, "objectName": "editNetworkFailoverRpcUrlInput", "type": "TextEdit", "visible": True}
editNetworkExplorerInput = {"container": statusDesktop_mainWindow, "objectName": "editNetworkExplorerInput", "type": "TextEdit"}
editNetworkAknowledgmentCheckbox = {"container": statusDesktop_mainWindow, "objectName": "editNetworkAknowledgmentCheckbox", "type": "StatusCheckBox", "visible": True}
editNetworkRevertButton = {"container": statusDesktop_mainWindow, "objectName": "editNetworkRevertButton", "type": "StatusButton", "visible": True}
editNetworkSaveButton = {"container": statusDesktop_mainWindow, "objectName": "editNetworkSaveButton", "type": "StatusButton", "visible": True}
mainRpcUrlInputObject = {"container": settingsContentBase_ScrollView, "objectName": "mainRpcInputObject", "type": "StatusInput", "visible": True}
failoverRpcUrlInputObject = {"container": settingsContentBase_ScrollView, "objectName": "failoverRpcUrlInputObject", "type": "StatusInput", "visible": True}

# Profile View
mainWindow_MyProfileView = {"container": statusDesktop_mainWindow, "type": "MyProfileView", "unnamed": 1, "visible": True}
displayName_StatusInput = {"container": statusDesktop_mainWindow, "objectName": "displayNameInput", "type": "StatusInput", "visible": True}
displayName_TextEdit = {"container": displayName_StatusInput, "type": "TextEdit", "unnamed": 1, "visible": True}
change_password_button = {"container": statusDesktop_mainWindow, "type": "StatusButton", "objectName": "profileSettingsChangePasswordButton", "visible": True}
bio_StatusInput = {"container": statusDesktop_mainWindow, "objectName": "bioInput", "type": "StatusInput", "visible": True}
bio_TextEdit = {"container": bio_StatusInput, "type": "TextEdit", "unnamed": 1, "visible": True}
addMoreSocialLinks = {"container": statusDesktop_mainWindow, "objectName": "addMoreSocialLinks", "type": "StatusLinkText", "visible": True}
mainWindow_profileTabBar_StatusTabBar = {"container": statusDesktop_mainWindow, "id": "profileTabBar", "type": "StatusTabBar", "unnamed": 1, "visible": True}
profileTabBar_Web_StatusTabButton = {"checkable": True, "container": mainWindow_profileTabBar_StatusTabBar, "objectName": "webTabButton", "type": "StatusTabButton", "visible": True}
profileTabBar_Identity_StatusTabButton = {"checkable": True, "container": mainWindow_profileTabBar_StatusTabBar, "objectName": "identityTabButton", "type": "StatusTabButton", "visible": True}

# Password view
mainWindow_PasswordView = {"container": statusDesktop_mainWindow, "type": "ChangePasswordView", "unnamed": 1, "visible": True}

# Syncing Settings View
mainWindow_SyncingView = {"container": statusDesktop_mainWindow, "type": "SyncingView", "unnamed": 1, "visible": True}
syncingInstructionsLayout = {"container": settingsContentBase_ScrollView, "id": "instructionsLayout", "type": "ColumnLayout", "unnamed": 1, "visible": True}
settings_Setup_Syncing_StatusButton = {"container": settingsContentBase_ScrollView, "objectName": "setupSyncingStatusButton", "type": "StatusButton", "visible": True}
settings_Sync_New_Device_Header = {"container": settingsContentBase_ScrollView, "objectName": "syncNewDeviceTextLabel", "type": "StatusBaseText", "visible": True}
settings_Sync_New_Device_SubTitle = {"container": settingsContentBase_ScrollView, "objectName": "syncNewDeviceSubTitleTextLabel", "type": "StatusBaseText", "visible": True}
unpairButton = {"container": settingsContentBase_ScrollView, "objectName": "unpairStatusButton", "type": "StatusButton", "visible": True}

#Sing out and quit View
signOutDialog = {"container": statusDesktop_mainWindow_overlay, "objectName": "ConfirmationDialog", "type": "PopupItem", "visible": True}
signOutConfirmationButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "signOutConfirmation", "type": "StatusButton", "visible": True}

# ENS usernames View
mainWindow_EnsWelcomeView = {"container": statusDesktop_mainWindow, "type": "EnsWelcomeView", "unnamed": 1, "visible": True}
mainWindow_Start_StatusButton = {"checkable": False, "container": statusDesktop_mainWindow, "objectName": "ensStartButton", "type": "StatusButton", "visible": True}
mainWindow_EnsSearchView = {"container": statusDesktop_mainWindow, "type": "EnsSearchView", "unnamed": 1, "visible": True}
mainWindow_ensUsernameInput_StyledTextField = {"container": statusDesktop_mainWindow, "objectName": "ensUsernameInput", "type": "StatusTextField", "visible": True}
mainWindow_ensNextButton_StatusRoundButton = {"container": statusDesktop_mainWindow, "objectName": "ensNextButton", "type": "StatusRoundButton", "visible": True}
ens_StatusBaseText = {"container": mainWindow_EnsSearchView, "type": "StatusBaseText", "unnamed": 1, "visible": True}
mainWindow_EnsTermsAndConditionsView = {"container": statusDesktop_mainWindow, "type": "EnsTermsAndConditionsView", "unnamed": 1, "visible": True}
mainWindow_sview_StatusScrollView = {"container": statusDesktop_mainWindow, "id": "sview", "type": "StatusScrollView", "unnamed": 1, "visible": True}
sview_walletAddressLbl_StatusDescriptionListItem = {"container": mainWindow_sview_StatusScrollView, "id": "walletAddressLbl", "type": "StatusDescriptionListItem", "unnamed": 1, "visible": True}
sview_keyLbl_StatusDescriptionListItem = {"container": mainWindow_sview_StatusScrollView, "id": "keyLbl", "type": "StatusDescriptionListItem", "unnamed": 1, "visible": True}
sview_ensAgreeTerms_StatusCheckBox = {"checkable": True, "container": mainWindow_sview_StatusScrollView, "objectName": "ensAgreeTerms", "type": "StatusCheckBox", "visible": True}
mainWindow_Register_StatusButton = {"checkable": False, "container": statusDesktop_mainWindow, "objectName": "ensStartTransaction", "text": "Register", "type": "StatusButton", "visible": True}
mainWindow_EnsRegisteredView = {"container": statusDesktop_mainWindow, "type": "EnsRegisteredView", "unnamed": 1, "visible": True}

# Advanced view
mainWindow_AdvancedView = {"container": statusDesktop_mainWindow, "type": "AdvancedView", "unnamed": 1, "visible": True}
mainWindow_settingsContentBaseScrollView_StatusScrollView = {"container": statusDesktop_mainWindow, "objectName": "settingsContentBaseScrollView", "type": "StatusScrollView", "visible": True}
manageCommunitiesOnTestnetButton_StatusSettingsLineButton = {"container": mainWindow_settingsContentBaseScrollView_StatusScrollView, "objectName": "manageCommunitiesOnTestnetButton", "type": "StatusSettingsLineButton", "visible": True}
rpcStatisticsButton = {"container": settingsContentBase_ScrollView, "id": "rpcStatsButton", "type": "StatusSettingsLineButton", "unnamed": 1, "visible": True}
enableCreateCommunityButton_StatusSettingsLineButton = {"container": settingsContentBase_ScrollView, "objectName": "enableCreateCommunityButton", "type": "StatusSettingsLineButton", "visible": True}
settingsContentBaseScrollViewLightWakuModeBloomSelectorButton = {"container": mainWindow_settingsContentBaseScrollView_StatusScrollView, "objectName": "lightWakuModeButton", "type": "BloomSelectorButton", "visible": True}
settingsContentBaseScrollViewRelayWakuModeBloomSelectorButton = {"container": mainWindow_settingsContentBaseScrollView_StatusScrollView, "objectName": "relayWakuModeButton", "type": "BloomSelectorButton", "visible": True}
