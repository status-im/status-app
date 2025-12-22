from objectmaphelper import *
from scripts.global_names import *
from enum import Enum

# Side bar section items object name helpers:
_MAIN_MENU_ITEM_OBJ_NAME = "-MainMenuItem"
_APP_MENU_ITEM_OBJ_NAME = "-AppMenuItem"
_SETTINGS_MENU_ITEM_OBJ_NAME = "-SettingsMenuItem"
_EXTRA_MENU_ITEM_OBJ_NAME = "-ExtraMenuItem"

# This is the exact enum definition done in app `Constants.qml` to determine each subsection itemId of each navigation list item
# These values are used to determine the dynamic `objectName` of the subsection item instead of using "design" properties like `text`.
class SettingsSubsection(Enum):
    PROFILE: str = "0" + _MAIN_MENU_ITEM_OBJ_NAME
    PASSWORD: str = "1" + _MAIN_MENU_ITEM_OBJ_NAME
    CONTACTS: str = "2" + _MAIN_MENU_ITEM_OBJ_NAME
    ENS_USERNAMES: str = "3" + _MAIN_MENU_ITEM_OBJ_NAME
    MESSAGING: str = "4" + _APP_MENU_ITEM_OBJ_NAME
    WALLET: str = "5" + _APP_MENU_ITEM_OBJ_NAME
    APPEARANCE: str = "6" + _SETTINGS_MENU_ITEM_OBJ_NAME
    LANGUAGE: str = "7" + _SETTINGS_MENU_ITEM_OBJ_NAME
    NOTIFICATIONS: str = "8" + _SETTINGS_MENU_ITEM_OBJ_NAME
    DEVICE_SETTINGS: str = "9" + _SETTINGS_MENU_ITEM_OBJ_NAME
    BROWSER: str = "10" + _APP_MENU_ITEM_OBJ_NAME
    ADVANCED: str = "11" + _SETTINGS_MENU_ITEM_OBJ_NAME
    ABOUT: str = "12" + _EXTRA_MENU_ITEM_OBJ_NAME
    COMMUNITY: str = "13" + _APP_MENU_ITEM_OBJ_NAME
    KEYCARD: str = "14" + _MAIN_MENU_ITEM_OBJ_NAME
    SIGNOUT: str = "17" + _EXTRA_MENU_ITEM_OBJ_NAME
    BACKUP_SEED: str = "18" + _MAIN_MENU_ITEM_OBJ_NAME

# Main:
navBarListView_Settings_navbar_PrimaryNavSidebarButton = {"checkable": True, "container": mainWindow_navBarListView_ListView, "objectName": "Settings-navbar", "type": "PrimaryNavSidebarButton", "visible": True}
settingsSave_StatusButton = {"container": statusDesktop_mainWindow, "objectName": "settingsDirtyToastMessageSaveButton", "type": "StatusButton", "visible": True}
settings_Sidebar_ENS_Item = {"container": mainWindow_ScrollView, "objectName": SettingsSubsection.ENS_USERNAMES.value, "type": "StatusNavigationListItem"}
settingsContentBase_ScrollView = {"container": statusDesktop_mainWindow, "objectName": "settingsContentBaseScrollView", "type": "StatusScrollView", "visible": True}
settingsContentBaseScrollView_Item = {"container": settingsContentBase_ScrollView, "type": "Item", "unnamed": 1, "visible": True}
mainWindow_LeftTabView = {"container": statusDesktop_mainWindow, "type": "LeftTabView", "unnamed": 1, "visible": True}
LeftTabView_ScrollView = {"container": mainWindow_LeftTabView, "type": "StatusScrollView", "unnamed": 1, "visible": True}


# ENS view;
settings_ENS_Start_Button = {"container": statusDesktop_mainWindow, "objectName": "ensStartButton", "type": "StatusButton"}
settings_ENS_Search_Input = {"container": statusDesktop_mainWindow, "objectName": "ensUsernameInput", "type": "StatusTextField"}
settings_ENS_Search_Next_Button = {"container": statusDesktop_mainWindow, "objectName": "ensNextButton", "type": "StatusRoundButton"}
settings_ENS_Terms_Agree = {"container": statusDesktop_mainWindow, "objectName": "ensAgreeTerms", "type": "StatusCheckBox"}
settings_ENS_Terms_Open_Transaction = {"container": statusDesktop_mainWindow, "objectName": "ensStartTransaction", "type": "StatusButton"}
settings_ENS_Terms_Transaction_Next_Button = {"container": statusDesktop_mainWindow, "objectName": "sendNextButton", "type": "StatusButton"}
settings_ENS_Terms_Transaction_Password_Input = {"container": statusDesktop_mainWindow, "objectName": "transactionSignerPasswordInput", "type": "StatusTextField"}

# Side bar items (Secondary navigation):
wallet_StatusNavigationListItem = {"container": mainWindow_ScrollView, "objectName": SettingsSubsection.WALLET.value, "type": "StatusNavigationListItem", "visible": True}
language_StatusNavigationListItem = {"container": mainWindow_ScrollView, "objectName": SettingsSubsection.LANGUAGE.value, "type": "StatusNavigationListItem", "visible": True}
advanced_StatusNavigationListItem = {"container": mainWindow_ScrollView, "objectName": SettingsSubsection.ADVANCED.value, "type": "StatusNavigationListItem", "visible": True}
keycard_StatusNavigationListItem = {"container": mainWindow_ScrollView, "objectName": SettingsSubsection.KEYCARD.value, "type": "StatusNavigationListItem", "visible": True}
sign_out_Quit_StatusNavigationListItem = {"container": mainWindow_ScrollView, "objectName": SettingsSubsection.SIGNOUT.value, "type": "StatusNavigationListItem", "visible": True}
communities_StatusNavigationListItem = {"container": mainWindow_ScrollView, "objectName": SettingsSubsection.COMMUNITY.value, "type": "StatusNavigationListItem", "visible": True}
profile_StatusNavigationListItem = {"container": mainWindow_ScrollView, "objectName": SettingsSubsection.PROFILE.value, "type": "StatusNavigationListItem", "visible": True}
messaging_StatusNavigationListItem = {"container": mainWindow_ScrollView, "objectName": SettingsSubsection.MESSAGING.value, "type": "StatusNavigationListItem", "visible": True}

# Profile Settings:
mainWindow_MyProfileView = {"container": statusDesktop_mainWindow, "type": "MyProfileView", "unnamed": 1, "visible": True}
displayName_StatusInput = {"container": statusDesktop_mainWindow, "objectName": "displayNameInput", "type": "StatusInput", "visible": True}
displayName_TextEdit = {"container": displayName_StatusInput, "type": "TextEdit", "unnamed": 1, "visible": True}
bio_StatusInput = {"container": statusDesktop_mainWindow, "objectName": "bioInput", "type": "StatusInput", "visible": True}
bio_TextEdit = {"container": bio_StatusInput, "type": "TextEdit", "unnamed": 1, "visible": True}
twitter_StaticSocialLinkInput = {"container": statusDesktop_mainWindow, "objectName": "__twitter-socialLinkInput", "type": "StaticSocialLinkInput", "visible": True}
twitter_TextEdit = {"container": twitter_StaticSocialLinkInput, "type": "TextEdit", "unnamed": 1, "visible": True}
personalSite_StaticSocialLinkInput = {"container": statusDesktop_mainWindow, "objectName": "__personal_site-socialLinkInput", "type": "StaticSocialLinkInput", "visible": True}
personalSite_TextEdit = {"container": personalSite_StaticSocialLinkInput, "type": "TextEdit", "unnamed": 1, "visible": True}
addMoreSocialLinks = {"container": statusDesktop_mainWindow, "objectName": "addMoreSocialLinks", "type": "StatusLinkText", "visible": True}
twitter_popup_StaticSocialLinkInput = {"container": statusDesktop_mainWindow_overlay, "objectName": "__twitter-socialLinkInput", "type": "StaticSocialLinkInput", "visible": True}
personalSite_popup_StaticSocialLinkInput = {"container": statusDesktop_mainWindow_overlay, "objectName": "__personal_site-socialLinkInput", "type": "StaticSocialLinkInput", "visible": True}
github_popup_StaticSocialLinkInput = {"container": statusDesktop_mainWindow_overlay, "objectName": "__github-socialLinkInput", "type": "StaticSocialLinkInput", "visible": True}
youtube_popup_StaticSocialLinkInput = {"container": statusDesktop_mainWindow_overlay, "objectName": "__youtube-socialLinkInput", "type": "StaticSocialLinkInput", "visible": True}
discord_popup_StaticSocialLinkInput = {"container": statusDesktop_mainWindow_overlay, "objectName": "__discord-socialLinkInput", "type": "StaticSocialLinkInput", "visible": True}
telegram_popup_StaticSocialLinkInput = {"container": statusDesktop_mainWindow_overlay, "objectName": "__telegram-socialLinkInput", "type": "StaticSocialLinkInput", "visible": True}
customLink_popup_StatusInput = {"container": statusDesktop_mainWindow_overlay, "objectName": "hyperlinkInput", "type": "StatusInput", "visible": True}
customUrl_popup_StatusInput = {"container": statusDesktop_mainWindow_overlay, "objectName": "urlInput", "type": "StatusInput", "visible": True}
customUrl_popup_TextEdit = {"container": customUrl_popup_StatusInput, "type": "TextEdit", "unnamed": 1, "visible": True}
change_password_button = {"container": statusDesktop_mainWindow, "type": "StatusButton", "objectName": "profileSettingsChangePasswordButton", "visible": True}

# Social Links Popup
socialLink_StatusListItem = {"container": statusDesktop_mainWindow_overlay, "type": "StatusListItem", "title": "", "visible": True}
placeholder_StatusBaseText = {"container": statusDesktop_mainWindow_overlay, "id": "placeholder", "type": "StatusBaseText", "unnamed": 1, "visible": True}
o_StatusBackButton = {"container": statusDesktop_mainWindow_overlay, "type": "StatusBackButton", "unnamed": 1, "visible": True}
add_StatusButton = {"checkable": False, "container": statusDesktop_mainWindow_overlay, "type": "StatusButton", "unnamed": 1, "visible": True}
linksView = {"container": statusDesktop_mainWindow, "id": "linksView", "type": "StatusListView", "unnamed": 1, "visible": True}
edit_TextEdit = {"container": statusDesktop_mainWindow_overlay, "type": "TextEdit", "unnamed": 1, "visible": True}

# Wallet Settings:
mainWallet_Saved_Addreses_More_Edit = {"container": statusDesktop_mainWindow, "objectName": "editSavedAddress", "type": "StatusMenuItem"}
mainWallet_Saved_Addreses_More_Delete = {"container": statusDesktop_mainWindow, "objectName": "deleteSavedAddress", "type": "StatusMenuItem"}
mainWallet_Saved_Addreses_More_Confirm_Delete = {"container": statusDesktop_mainWindow, "objectName": "RemoveAccountPopup-ConfirmButton", "type": "StatusButton"}
settings_Wallet_MainView_GeneratedAccounts = {"container": statusDesktop_mainWindow, "objectName": 'generatedAccounts', "type": 'Repeater'}
settings_Wallet_AccountView_DeleteAccount = {"container": statusDesktop_mainWindow, "type": "StatusButton", "objectName": "deleteAccountButton"}
settings_Wallet_AccountView_DeleteAccount_Confirm = {"container": statusDesktop_mainWindow, "type": "StatusButton", "objectName": "confirmDeleteAccountButton"}
mainWindow_ScrollView_2 = {"container": statusDesktop_mainWindow, "occurrence": 2, "type": "StatusScrollView", "unnamed": 1, "visible": True}
settings_Wallet_MainView_Networks = {"container": statusDesktop_mainWindow, "objectName": "networksItem", "type": "StatusListItem"}
settings_Wallet_NetworksView_TestNet_Toggle = {"container": statusDesktop_mainWindow, "objectName": "testnetModeSwitch", "type": "StatusSwitch"}
settings_Wallet_AccountView_EditAccountButton = {"container": statusDesktop_mainWindow, "type": "StatusButton", "objectName": "walletAccountViewEditAccountButton"}
settings_Wallet_AccountView_EditAccountNameInput = {"container": statusDesktop_mainWindow_overlay, "type": "TextEdit", "objectName": "renameAccountNameInput", "visible": True}
settings_Wallet_AccountView_EditAccountSaveButton = {"container": statusDesktop_mainWindow_overlay, "type": "StatusButton", "objectName": "renameAccountModalSaveBtn"}
settings_Wallet_AccountView_EditAccountColorRepeater = {"container": statusDesktop_mainWindow, "type": "Repeater", "objectName": "statusColorRepeater", "visible": True}
settings_Wallet_AccountView_AccountName = {"container": statusDesktop_mainWindow, "type": "StatusBaseText", "objectName": "walletAccountViewAccountName"}
settings_Wallet_AccountView_IconSettings = {"container": statusDesktop_mainWindow, "type": "StatusEmoji", "objectName": "walletAccountViewAccountImage" , "visible": True}
settings_Wallet_MainView_BackupSeedPhrase = {"container": mainWindow_ScrollView, "objectName": SettingsSubsection.BACKUP_SEED.value, "type": "StatusNavigationListItem", "visible": True}
settings_Wallet_MainView_AddNewAccountButton = {"container": statusDesktop_mainWindow, "objectName": "settings_Wallet_MainView_AddNewAccountButton", "type": "StatusButton", "visible": True}

generatedAccounts_ListView = {"container": statusDesktop_mainWindow, "objectName": "generatedAccounts", "type": "ListView"}

# Messaging Settings:
displayMessageLinkPreviewItem = {"container": statusDesktop_mainWindow, "objectName": "displayMessageLinkPreviewsItem", "type": "StatusListItem"}
linkPreviewSwitch = {"container": statusDesktop_mainWindow, "objectName": "MessagingView_showMessageLinksSwitch", "type": "StatusSwitch", "visible": True}
imageUnfurlingItem = {"container": statusDesktop_mainWindow, "objectName": "imageUnfurlingItem", "type": "StatusListItem"}
showGifPreviewsSwitch = {"container": settingsContentBase_ScrollView, "id": "showGifPreviewsSwitch", "type": "StatusSwitch", "unnamed": 1, "visible": True}
contacts_listItem_btn = {"container": statusDesktop_mainWindow, "objectName": "MessagingView_ContactsListItem_btn", "type": "StatusContactRequestsIndicatorListItem"}
settingsContentBaseScrollView_StatusScrollBar = {"container": settingsContentBase_ScrollView, "occurrence": 3, "type": "StatusScrollBar", "unnamed": 1, "visible": True}

# Contacts View
contact_request_to_chat_key_btn = {"container": statusDesktop_mainWindow, "objectName": "ContactsView_ContactRequest_Button", "type": "StatusButton"}
contactRequest_ChatKey_Input = {"container": statusDesktop_mainWindow, "objectName": "SendContactRequestModal_ChatKey_Input", "type": "TextEdit"}
contactRequest_SayWhoYouAre_Input = {"container": statusDesktop_mainWindow, "objectName": "SendContactRequestModal_SayWhoYouAre_Input", "type": "TextEdit"}
contactRequest_Send_Button = {"container": statusDesktop_mainWindow, "objectName": "SendContactRequestModal_Send_Button", "type": "StatusButton"}
contactRequest_PendingRequests_Button = {"container": statusDesktop_mainWindow, "objectName": "ContactsView_PendingRequest_Button", "type": "StatusTabButton"}
sentRequests_ContactsListPanel = {"container": settingsContentBase_ScrollView, "objectName": "sentRequests_ContactsListPanel", "type": "ContactsListPanel"}
sentRequests_contactListPanel_ListView = {"container": sentRequests_ContactsListPanel, "objectName": "ContactListPanel_ListView", "type": "StatusListView"}
receivedRequests_ContactsListPanel = {"container": settingsContentBase_ScrollView, "objectName": "receivedRequests_ContactsListPanel", "type": "ContactsListPanel"}
receivedRequests_contactListPanel_ListView = {"container": receivedRequests_ContactsListPanel, "objectName": "ContactListPanel_ListView", "type": "StatusListView"}
ProfilePopup_SayWhoYouAre_TextEdit = {"container": statusDesktop_mainWindow_overlay, "objectName": "ProfileSendContactRequestModal_sayWhoYouAreInput", "type": "TextEdit"}
ProfilePopup_SendContactRequest_Button = {"container": statusDesktop_mainWindow_overlay, "objectName": "ProfileSendContactRequestModal_sendContactRequestButton", "type": "StatusButton"}

# Communities Settings:
settings_Communities_CommunitiesListPanel = { "container": statusDesktop_mainWindow, "objectName": "CommunitiesView_communitiesListPanel", "type": "StatusListView" }
settings_Communities_MainView_LeaveCommunityButtons = { "container": statusDesktop_mainWindow, "objectName": "CommunitiesListPanel_leaveCommunityPopupButton", "type": "StatusBaseButton", "visible": True }
settings_Communities_MainView_LeavePopup_LeaveCommunityButton = {"container": statusDesktop_mainWindow, "objectName":"CommunitiesListPanel_leaveCommunityButtonInPopup", "type": "StatusBaseButton", "visible": True}

# Advanced Settings:
walletSettingsLineButton = {"container": statusDesktop_mainWindow, "objectName": "WalletSettingsLineButton", "type": "StatusSettingsLineButton", "visible": True}
communitySettingsLineButton = {"container": statusDesktop_mainWindow, "objectName": "CommunitySettingsLineButton", "type": "StatusSettingsLineButton", "visible": True}
i_understand_StatusBaseText = {"container": statusDesktop_mainWindow_overlay, "text": "I understand", "type": "StatusBaseText", "unnamed": 1, "visible": True}

# Extra Settings:
signOutConfirmation_StatusButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "signOutConfirmation", "type": "StatusButton", "visible": True}

# Language Settings:
settings_LanguageView = {"container": statusDesktop_mainWindow, "objectName": "languageView", "type": "LanguageView"}
languageView_language_StatusListPicker = {"container": statusDesktop_mainWindow, "objectName": "languagePicker", "type": "StatusListPicker"}
languageView_language_StatusPickerButton = {"container": languageView_language_StatusListPicker,  "type": "StatusPickerButton", "unnamed": 1}
languageView_language_ListView = {"container": languageView_language_StatusListPicker,  "type": "ListView", "unnamed": 1}
languageView_language_StatusInput = {"container": languageView_language_ListView,  "type": "StatusInput", "unnamed": 1}

# Backup seed phrase:
backup_seed_phrase_popup_Acknowledgements_havePen_checkbox = {"container": statusDesktop_mainWindow_overlay, "objectName": "Acknowledgements_havePen", "type": "StatusCheckBox", "checkable": True, "visible": True}
backup_seed_phrase_popup_Acknowledgements_writeDown_checkbox = {"container": statusDesktop_mainWindow_overlay, "objectName": "Acknowledgements_writeDown", "type": "StatusCheckBox", "checkable": True, "visible": True}
backup_seed_phrase_popup_Acknowledgements_storeIt_checkbox = {"container": statusDesktop_mainWindow_overlay, "objectName": "Acknowledgements_storeIt", "type": "StatusCheckBox", "checkable": True, "visible": True}
backup_seed_phrase_popup_nextButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "BackupSeedModal_nextButton", "type": "StatusButton", "visible": True, "enabled": True}
backup_seed_phrase_popup_ConfirmSeedPhrasePanel_RevealSeedPhraseButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "ConfirmSeedPhrasePanel_RevealSeedPhraseButton", "type": "StatusButton", "visible": True}
backup_seed_phrase_popup_ConfirmSeedPhrasePanel_StatusSeedPhraseInput_placeholder = {"container": statusDesktop_mainWindow_overlay, "objectName": "ConfirmSeedPhrasePanel_StatusSeedPhraseInput_%WORD_NO%", "type": "StatusSeedPhraseInput", "visible": True}
backup_seed_phrase_popup_BackupSeedStepBase_confirmFirstWord = {"container": statusDesktop_mainWindow_overlay, "objectName": "BackupSeedModal_BackupSeedStepBase_confirmFirstWord", "type": "BackupSeedStepBase", "visible": True}
backup_seed_phrase_popup_BackupSeedStepBase_confirmFirstWord_inputText = {"container": backup_seed_phrase_popup_BackupSeedStepBase_confirmFirstWord, "objectName": "BackupSeedStepBase_inputText", "type": "TextEdit", "visible": True}
backup_seed_phrase_popup_BackupSeedStepBase_confirmSecondWord = {"container": statusDesktop_mainWindow_overlay, "objectName": "BackupSeedModal_BackupSeedStepBase_confirmSecondWord", "type": "BackupSeedStepBase", "visible": True}
backup_seed_phrase_popup_BackupSeedStepBase_confirmSecondWord_inputText = {"container": backup_seed_phrase_popup_BackupSeedStepBase_confirmSecondWord, "objectName": "BackupSeedStepBase_inputText", "type": "TextEdit", "visible": True}
backup_seed_phrase_popup_ConfirmStoringSeedPhrasePanel_storeCheck = {"container": statusDesktop_mainWindow_overlay, "objectName": "ConfirmStoringSeedPhrasePanel_storeCheck", "type": "StatusCheckBox", "checkable": True, "visible": True}
backup_seed_phrase_popup_BackupSeedModal_completeAndDeleteSeedPhraseButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "BackupSeedModal_completeAndDeleteSeedPhraseButton", "type": "StatusButton", "visible": True}

# User Status Profile Menu
userContextmenu_AlwaysActiveButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "userStatusMenuAlwaysOnlineAction", "type": "StatusMenuItem", "visible": True, "enabled": True}
userContextmenu_InActiveButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "userStatusMenuInactiveAction", "type": "StatusMenuItem", "visible": True, "enabled": True}
userContextmenu_AutomaticButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "userStatusMenuAutomaticAction", "type": "StatusMenuItem", "visible": True, "enabled": True}

# Change Password Menu 
change_password_menu_current_password = {"container": statusDesktop_mainWindow_overlay, "objectName": "passwordViewCurrentPassword", "type": "StatusPasswordInput", "visible": True}
change_password_menu_new_password = {"container": statusDesktop_mainWindow_overlay, "objectName": "passwordViewNewPassword", "type": "StatusPasswordInput", "visible": True}
change_password_menu_new_password_confirm = {"container": statusDesktop_mainWindow_overlay, "objectName": "passwordViewNewPasswordConfirm", "type": "StatusPasswordInput", "visible": True}
change_password_menu_submit_button = {"container": statusDesktop_mainWindow_overlay, "objectName": "changePasswordModalSubmitButton", "type": "StatusButton", "visible": True}
change_password_success_menu_sign_out_quit_button = {"container": statusDesktop_mainWindow_overlay, "objectName": "changePasswordSuccessModalSignOutAndQuitButton", "type": "StatusButton", "visible": True}
