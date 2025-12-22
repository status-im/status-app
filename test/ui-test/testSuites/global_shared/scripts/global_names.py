from objectmaphelper import *

statusDesktop_mainWindow = {"name": "mainWindow", "type": "Window", "visible": True}
statusDesktop_mainWindow_overlay = {"container": statusDesktop_mainWindow, "type": "Overlay", "unnamed": 1, "visible": True}
scrollView_StatusScrollView = {"container": statusDesktop_mainWindow_overlay, "id": "scrollView", "type": "StatusScrollView", "unnamed": 1, "visible": True}
statusDesktop_mainWindow_overlay_popup = {"container": statusDesktop_mainWindow_overlay, "type": "PopupItem", "unnamed": 1, "visible": True}
statusDesktop_mainWindow_overlay_popup2 = {"container": statusDesktop_mainWindow_overlay, "occurrence": 2, "type": "PopupItem", "unnamed": 1, "visible": True}
mainWindow_navBarListView_ListView = {"container": statusDesktop_mainWindow, "objectName": "statusMainNavBarListView", "type": "ListView", "visible": True}
mainWindow_communityNavBarListView_ListView = {"container": statusDesktop_mainWindow, "objectName": "statusCommunityMainNavBarListView", "type": "ListView", "visible": True}
chatView_log = {"container": statusDesktop_mainWindow, "objectName": "chatLogView", "type": "StatusListView", "visible": True}
statusDesktop_mainWindow_AppMain_EmojiPopup_SearchTextInput = {"container": statusDesktop_mainWindow_overlay, "objectName": "StatusEmojiPopup_searchBox", "type": "TextEdit", "visible": True}
mainWindow_ScrollView = {"container": statusDesktop_mainWindow, "type": "StatusScrollView", "unnamed": 1, "visible": True}
mainWindow_ScrollView_2 = {"container": statusDesktop_mainWindow, "occurrence": 2, "type": "StatusScrollView", "unnamed": 1, "visible": True}
mainWindow_ProfileNavBarButton = {"container": statusDesktop_mainWindow, "objectName": "statusProfileNavBarTabButton", "type": "PrimaryNavSidebarButton", "visible": True}
mainWindow_ProfileSettingsView = {"container": statusDesktop_mainWindow, "objectName": "myProfileSettingsView", "type": "ColumnLayout", "visible": True}
settings_navbar_settings_icon_StatusIcon = {"container": mainWindow_navBarListView_ListView, "objectName": "settings-icon", "type": "StatusIcon", "visible": True}
splashScreen = {"container": statusDesktop_mainWindow, "objectName": "splashScreen", "type": "DidYouKnowSplashScreen"}
mainWindow_StatusToolBar = {"container": statusDesktop_mainWindow, "objectName": "statusToolBar", "type": "StatusToolBar", "visible": True}
main_toolBar_back_button = {"container": mainWindow_StatusToolBar, "objectName": "toolBarBackButton", "type": "StatusFlatButton", "visible": True}
mainWindow_emptyChatPanelImage = {"container": statusDesktop_mainWindow, "objectName": "emptyChatPanelImage", "type": "Image", "visible": True}
viewProfile_MenuItem = {"container": statusDesktop_mainWindow_overlay, "objectName": "viewProfileMenuItem", "type": "StatusMenuItem", "visible": True}
mainWindow_ContactsColumn_Messages_Headline = {"container": statusDesktop_mainWindow, "objectName": "ContactsColumnView_MessagesHeadline", "type": "StatusNavigationPanelHeadline"}

# main right panel
mainWindow_RighPanel = {"container": statusDesktop_mainWindow, "type": "ColumnLayout", "objectName": "mainRightView", "visible": True}

# Navigation Panel
mainWindow_StatusAppNavBar = {"container": statusDesktop_mainWindow, "type": "StatusAppNavBar", "unnamed": 1, "visible": True}

# User Status Profile Menu
o_StatusListView = {"container": statusDesktop_mainWindow_overlay, "type": "StatusListView", "unnamed": 1, "visible": True}
userContextmenu_AlwaysActiveButton= {"container": o_StatusListView, "objectName": "userStatusMenuAlwaysOnlineAction", "type": "StatusMenuItem", "visible": True}
userContextmenu_InActiveButton= {"container": o_StatusListView, "objectName": "userStatusMenuInactiveAction", "type": "StatusMenuItem", "visible": True}
userContextmenu_AutomaticButton= {"container": o_StatusListView, "objectName": "userStatusMenuAutomaticAction", "type": "StatusMenuItem", "visible": True}
userContextMenu_ViewMyProfileAction = {"container": o_StatusListView, "objectName": "userStatusViewMyProfileAction", "type": "StatusMenuItem", "visible": True}

# popups
modal_Close_Button = {"container": statusDesktop_mainWindow_overlay, "objectName": "headerCloseButton", "type": "StatusFlatRoundButton", "visible": True}
delete_Channel_ConfirmationDialog_DeleteButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "deleteChatConfirmationDialogDeleteButton", "type": "StatusButton"}
closeButton_StatusHeaderAction = {"container": statusDesktop_mainWindow_overlay, "objectName": "headerActionsCloseButton", "type": "StatusFlatRoundButton", "visible": True}

# Main Window - chat related:
mainWindow_statusChatNavBarListView_ListView = {"container": statusDesktop_mainWindow, "objectName": "statusChatNavBarListView", "type": "ListView", "visible": True}
navBarListView_Chat_navbar_PrimaryNavSidebarButton = {"checkable": True, "container": mainWindow_statusChatNavBarListView_ListView, "objectName": "Messages-navbar", "type": "PrimaryNavSidebarButton", "visible": True}
chatList_ListView = {"container": statusDesktop_mainWindow, "objectName": "chatListItems", "type": "StatusListView", "visible": True}
chatList = {"container": statusDesktop_mainWindow, "objectName": "ContactsColumnView_chatList", "type": "StatusChatList"}
mainWindow_startChat = {"checkable": True, "container": statusDesktop_mainWindow, "objectName": "startChatButton", "type": "StatusIconTabButton"}
chatView_messageInput = {"container": statusDesktop_mainWindow, "objectName": "messageInputField", "type": "TextArea", "visible": True}
chatView_StatusChatInfoButton = {"container": statusDesktop_mainWindow, "objectName": "chatInfoBtnInHeader", "type": "StatusChatInfoButton", "visible": True}
chatInfoButton_Pin_Text = {"container": chatView_StatusChatInfoButton, "objectName": "StatusChatInfo_pinText", "type": "StatusBaseText", "visible": True}
startChat_Btn = {"container": statusDesktop_mainWindow_overlay, "objectName": "startChatButton", "type": "StatusButton"}
chatButtonsPanelConfirmDeleteMessageButton_StatusButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "chatButtonsPanelConfirmDeleteMessageButton", "type": "StatusButton"}
chatView_chatLogView_lastMsg_MessageView = {"container": chatView_log, "index": 0, "type": "MessageView"}
chatView_lastChatText_Text = {"container": chatView_chatLogView_lastMsg_MessageView, "type": "TextEdit", "objectName": "StatusTextMessage_chatText", "visible": True}
chatView_gifPopupButton = {"container": statusDesktop_mainWindow, "objectName": "gifPopupButton", "type": "StatusFlatRoundButton", "visible": True}
chatView_ChatToolbarMoreOptionsButton = {"container": statusDesktop_mainWindow, "objectName": "chatToolbarMoreOptionsButton", "type": "StatusFlatRoundButton", "visible": True}
chatView_chatLogView_lastMsg_MessageView = {"container": chatView_log, "index": 0, "type": "MessageView"}
chatView_SuggestionBoxPanel ={"container": statusDesktop_mainWindow, "objectName": "suggestionsBox", "type": "SuggestionBoxPanel", "visible": True}
chatView_suggestion_ListView ={"container": chatView_SuggestionBoxPanel, "objectName": "suggestionBoxList", "type": "StatusListView", "visible": True}
chatView_userMentioned_ProfileView ={"container": statusDesktop_mainWindow_overlay, "objectName": "profileView", "type": "ProfileView", "visible": True}
chatView_ChatToolbarMoreOptionsButton = {"container": statusDesktop_mainWindow, "objectName": "chatToolbarMoreOptionsButton", "type": "StatusFlatRoundButton", "visible": True}

# Gif popup:
gifPopup_enableGifButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "enableGifsButton", "type": "StatusButton"}
gifPopup_gifMouseArea = {"container": statusDesktop_mainWindow_overlay, "objectName": "gifMouseArea_1", "type": "MouseArea"}

# My Profile Popup
ProfileHeader_userImage = {"container": statusDesktop_mainWindow_overlay, "objectName": "ProfileHeader_userImage", "type": "UserImage", "visible": True}
ProfilePopup_displayName = {"container": statusDesktop_mainWindow_overlay, "objectName": "ProfileDialog_displayName", "type": "StatusBaseText", "visible": True}
ProfilePopup_editButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "editProfileButton", "type": "StatusButton", "visible": True}
ProfilePopup_SendContactRequestButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "profileDialog_sendContactRequestButton", "type": "StatusButton", "visible": True}

# Banners
mainWindow_secureYourSeedPhraseBanner_ModuleWarning = {"container": statusDesktop_mainWindow, "objectName": "secureYourSeedPhraseBanner", "type": "ModuleWarning", "visible": True}

# Context Menu
contextMenu_PopupItem = {"container": statusDesktop_mainWindow_overlay, "type": "PopupItem", "unnamed": 1, "visible": True}
contextMenuItem = {"container": statusDesktop_mainWindow_overlay, "type": "StatusBaseText", "unnamed": 1, "visible": True}

# Confirmation Popup
confirmButton = {"container": statusDesktop_mainWindow_overlay, "objectName": RegularExpression("confirm*"), "type": "StatusButton"}

# Emoji Popup
mainWallet_AddEditAccountPopup_AccountEmojiSearchBox = {"container": statusDesktop_mainWindow, "objectName": "StatusEmojiPopup_searchBox", "type": "TextEdit", "visible": True}
mainWallet_AddEditAccountPopup_AccountEmoji = {"container": statusDesktop_mainWindow, "type": "StatusEmoji", "visible": True}
