from scripts.global_names import *

# Main:
mainWindow_Window = {"name": "mainWindow", "type": "Window", "visible": True}
mainWindow_communityColumnView_CommunityColumnView = {"container": statusDesktop_mainWindow, "objectName": "communityColumnView", "type": "CommunityColumnView", "visible": True}
mainWindow_communityHeader_StatusChatInfoButton = {"container": statusDesktop_mainWindow, "objectName": "communityHeaderButton", "type": "StatusChatInfoButton", "visible": True}
community_ChatInfo_Name_Text = {"container": mainWindow_communityHeader_StatusChatInfoButton, "objectName": "statusChatInfoButtonNameText", "type": "StatusBaseText", "visible": True}
mainWindow_createChannelOrCategoryBtn_StatusBaseText = {"container": statusDesktop_mainWindow, "objectName": "createChannelOrCategoryBtn", "type": "StatusBaseText", "visible": True}
create_channel_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "createCommunityChannelBtn", "type": "StatusMenuItem", "visible": True}
create_category_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "createCommunityCategoryBtn", "type": "StatusMenuItem", "visible": True}
edit_сategory_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "editCategoryMenuItem", "type": "StatusMenuItem", "visible": True}
delete_сategory_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "deleteCategoryMenuItem", "type": "StatusMenuItem", "visible": True}
confirmDeleteCategoryButton_StatusButton = {"container": statusDesktop_mainWindow, "objectName": "confirmDeleteCategoryButton", "type": "StatusButton"}
chat_moreOptions_menuButton = {"container": statusDesktop_mainWindow, "objectName": "chatToolbarMoreOptionsButton", "type": "StatusFlatRoundButton", "visible": True}
edit_Channel_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "editChannelMenuItem", "type": "StatusMenuItem", "visible": True}
delete_Channel_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "enabled": True, "objectName": "deleteOrLeaveMenuItem", "type": "StatusMenuItem", "visible": True}
mainWindow_communityColumnView_statusChatList = {"container": mainWindow_communityColumnView_CommunityColumnView, "objectName": "statusChatListAndCategoriesChatList", "type": "StatusChatList"}
mainWindow_chatInfoBtnInHeader_StatusChatInfoButton = {"container": statusDesktop_mainWindow, "objectName": "chatInfoBtnInHeader", "type": "StatusChatInfoButton", "visible": True}
chatInput_Root = {"container": statusDesktop_mainWindow, "objectName": "statusChatInput", "type": "Rectangle", "visible": True}
emojiPopup_Emoji_Button_Placeholder = {"container": statusDesktop_mainWindow, "objectName": "statusEmoji_%NAME%", "type": "StatusEmoji", "visible": True}
community_AddMembers_Button = {"container": statusDesktop_mainWindow, "objectName": "CommunityWelcomeBannerPanel_AddMembersButton", "type": "StatusButton", "visible": True}
community_ManageCommunity_Button = {"container": statusDesktop_mainWindow, "objectName": "CommunityWelcomeBannerPanel_ManageCommunity", "type": "StatusFlatButton", "visible": True}
community_InviteFirends_Popup_InvitePanel = {"container": statusDesktop_mainWindow_overlay, "objectName": "CommunityProfilePopupInviteFrindsPanel_ColumnLayout", "type": "ColumnLayout", "visible": True}
community_InviteFirends_Popup_ExistinContacts_ListView = {"container": community_InviteFirends_Popup_InvitePanel, "objectName": "ExistingContacts_ListView", "type": "StatusListView", "visible": True}
community_InviteFriendsToCommunityPopup_NextButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "InviteFriendsToCommunityPopup_NextButton", "type": "StatusButton", "visible": True}
community_InviteFriends_Popup_MessagePanel = {"container": statusDesktop_mainWindow_overlay, "objectName": "CommunityProfilePopupInviteMessagePanel_ColumnLayout", "type": "ColumnLayout", "visible": True}
community_ProfilePopupInviteMessagePanel_MessageInput = {"container": community_InviteFriends_Popup_MessagePanel, "objectName": "CommunityProfilePopupInviteMessagePanel_MessageInput", "type": "TextEdit", "visible": True}
community_InviteFriend_SendButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "InviteFriendsToCommunityPopup_SendButton", "type": "StatusButton", "visible": True}
communitySettings_Members_NavigationListItem = {"container": statusDesktop_mainWindow, "objectName": "CommunitySettingsView_NavigationListItem_Members", "type": "StatusNavigationListItem", "visible": True}
communitySettingsView_NavigationListItem_Airdrops = {"container": statusDesktop_mainWindow, "objectName": "CommunitySettingsView_NavigationListItem_Airdrops", "type": "StatusNavigationListItem", "visible": True}
communitySettingsView_NavigationListItem_Mint_Tokens = {"container": statusDesktop_mainWindow, "objectName": "CommunitySettingsView_NavigationListItem_Tokens", "type": "StatusNavigationListItem", "visible": True}
communitySettings_Permissions_NavigationListItem = {"container": statusDesktop_mainWindow, "objectName": "CommunitySettingsView_NavigationListItem_Permissions", "type": "StatusNavigationListItem", "visible": True}
communitySettingsView_NavigationListItem_Overview = {"container": statusDesktop_mainWindow, "objectName": "CommunitySettingsView_NavigationListItem_Overview", "type": "StatusNavigationListItem", "visible": True}
communitySettings_MembersTab_Members_ListView = {"container": statusDesktop_mainWindow, "objectName": "CommunityMembersTabPanel_MembersListViews", "type": "ListView", "visible": True}
communitySettings_MembersTab_Member_Kick_Button = {"container": communitySettings_MembersTab_Members_ListView, "objectName": "MemberListItem_KickButton", "type": "StatusButton", "visible": True}
communitySettings_KickModal_Kick_Button = {"container": statusDesktop_mainWindow_overlay, "objectName": "CommunityMembers_KickModal_KickButton", "type": "StatusButton", "visible": True}

# Chat components
chatView_TogglePinMessageButton = {"container": chatView_log, "objectName": "MessageView_toggleMessagePin", "type": "StatusFlatRoundButton", "visible": True}
chatView_ReplyToMessageButton = {"container": chatView_log, "objectName": "replyToMessageButton", "type": "StatusFlatRoundButton", "visible": True}
chatView_editComposerInputComponent = {"container": statusDesktop_mainWindow, "objectName": "statusChatInput", "type": "StatusChatInputNew", "visible": True}
chatView_editComposerTextArea = {"container": chatView_editComposerInputComponent, "objectName": "messageInputField", "type": "TextArea", "visible": True}
clearHistoryMenuItem = {"container": statusDesktop_mainWindow_overlay, "objectName": "clearHistoryMenuItem", "type": "StatusMenuItem", "visible": True}
chatView_unfurledImageComponent_linkImage = {"container": chatView_log, "objectName": "LinksMessageView_unfurledImageComponent_linkImage", "type": "StatusChatImageLoader",  "visible": True}
emojiSuggestions_first_inputListRectangle ={"container": statusDesktop_mainWindow_overlay, "objectName": "inputListRectangle_0", "type": "Rectangle"}
chatInput_Emoji_Button = {"container": statusDesktop_mainWindow, "objectName": "statusChatInputEmojiButton", "type": "StatusFlatRoundButton", "visible": True}
chat_Input_Stickers_Button = {"container": statusDesktop_mainWindow, "objectName": "statusChatInputStickersButton", "type": "StatusFlatRoundButton", "visible": True}
mark_as_Read_StatusMenuItem = {"container": statusDesktop_mainWindow_overlay, "objectName": "chatMarkAsReadMenuItem", "type": "StatusMenuItem", "visible": True}

# Stickers Popup
chat_StickersPopup_GetStickers_Button = {"container": statusDesktop_mainWindow_overlay, "objectName": "stickersPopupGetStickersButton", "type": "StatusButton", "visible": True}
chat_StickersPopup_Retry_Button = {"container": statusDesktop_mainWindow_overlay, "objectName": "stickersPopupRetryButton", "type": "StatusButton", "visible": True}
chat_StickersPopup_StickerMarket_GridView = {"container": statusDesktop_mainWindow_overlay, "objectName": "stickerMarketStatusGridView", "type": "StatusGridView", "visible": True}
chat_StickersPopup_StickerMarket_DelegateItem_1 = {"container": chat_StickersPopup_StickerMarket_GridView, "objectName": "stickerMarketDelegateItem1", "type": "Item", "visible": True}
chat_StickersPopup_StickerMarket_Install_Button = {"container": statusDesktop_mainWindow_overlay, "objectName": "statusStickerMarketInstallButton", "type": "StatusStickerButton", "visible": True}
chat_StickersPopup_StickerList_Grid = {"container": statusDesktop_mainWindow_overlay, "objectName": "statusStickerPopupStickerGrid", "type": "StatusStickerList", "visible": True}

# Community channel popup:
createOrEditCommunityChannelNameInput_TextEdit = {"container": statusDesktop_mainWindow_overlay, "objectName": "createOrEditCommunityChannelNameInput", "type": "TextEdit", "visible": True}
createOrEditCommunityChannelDescriptionInput_TextEdit = {"container": statusDesktop_mainWindow_overlay, "objectName": "createOrEditCommunityChannelDescriptionInput", "type": "TextEdit", "visible": True}
createOrEditCommunityChannelBtn_StatusButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "createOrEditCommunityChannelBtn", "type": "StatusButton", "visible": True}
createOrEditCommunityChannel_EmojiButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "StatusChannelPopup_emojiButton", "type": "StatusRoundButton", "visible": True}
createOrEditCommunityChannel_Emoji_Button_Placeholder = {"container": statusDesktop_mainWindow, "objectName": "statusEmoji_%NAME%", "type": "StatusEmoji", "visible": True}

# Community category popup:
createOrEditCommunityCategoryNameInput_TextEdit = {"container": statusDesktop_mainWindow_overlay, "objectName": "createOrEditCommunityCategoryNameInput", "type": "TextEdit", "visible": True}
createOrEditCommunityCategoryChannelList_ListView = {"container": statusDesktop_mainWindow_overlay, "objectName": "createOrEditCommunityCategoryChannelList", "type": "StatusListView", "visible": True}
createOrEditCommunityCategoryChannelList_ListItem_Placeholder = {"container": createOrEditCommunityCategoryChannelList_ListView, "objectName": "%NAME%", "type": "StatusListItem", "visible": True}
createOrEditCommunityCategoryBtn_StatusButton = {"container": statusDesktop_mainWindow_overlay, "objectName": "createOrEditCommunityCategoryBtn", "type": "StatusButton", "visible": True}

# Community settings
communitySettings_EditCommunity_Button = {"container": statusDesktop_mainWindow, "objectName": "communityOverviewSettingsEditCommunityButton", "type": "StatusButton", "visible": True}
communitySettings_BackToCommunity_Button = {"container": statusDesktop_mainWindow, "objectName": "communitySettingsBackToCommunityButton", "type": "StatusBaseText", "visible": True}
communitySettings_CommunityName_Text = {"container": statusDesktop_mainWindow, "objectName": "communityOverviewSettingsCommunityName", "type": "StatusBaseText", "visible": True}
communitySettings_CommunityDescription_Text = {"container": statusDesktop_mainWindow, "objectName": "communityOverviewSettingsCommunityDescription", "type": "StatusBaseText", "visible": True}
communitySettings_Community_Identicon = {"container": statusDesktop_mainWindow, "objectName": "communityOverviewSettingsPanelIdenticon", "type": "StatusSmartIdenticon", "visible": True}

# Community Edit:
communitySettings_EditCommunity_ScrollView = {"container": statusDesktop_mainWindow, "objectName": "communityEditPanelScrollView", "type": "StatusScrollView", "visible": True}
communitySettings_EditCommunity_Name_Input = {"container": communitySettings_EditCommunity_ScrollView, "objectName": "communityNameInput", "type": "TextEdit",  "visible": True}
communitySettings_EditCommunity_Description_Input = {"container": communitySettings_EditCommunity_ScrollView, "objectName": "communityDescriptionInput", "type": "TextEdit",  "visible": True}
communitySettings_EditCommunity_ColorPicker_Button = {"container": communitySettings_EditCommunity_ScrollView, "objectName": "communityColorPicker", "type": "ColorPicker", "visible": True}

# Community color popup:
communitySettings_ColorPanel_HexColor_Input = {"container": statusDesktop_mainWindow_overlay, "objectName": "communityColorPanelHexInput", "type": "TextEdit",  "visible": True}
communitySettings_SaveColor_Button = {"container": statusDesktop_mainWindow_overlay, "objectName": "communityColorPanelSelectColorButton", "type": "StatusButton", "visible": True}

# Community transfer ownership
copyCommunityPrivateKeyButton = {"container": statusDesktop_mainWindow, "objectName": "copyCommunityPrivateKeyButton", "type": "StatusButton", "visible": True}

# Community welcome screen
community_welcome_screen_image = {"container": statusDesktop_mainWindow, "objectName": "welcomeSettingsImage", "type": "Image", "visible": True}
community_welcome_screen_title = {"container": statusDesktop_mainWindow, "objectName": "welcomeSettingsTitle", "type": "StatusBaseText", "visible": True}
community_welcome_screen_subtitle = {"container": statusDesktop_mainWindow, "objectName": "welcomeSettingsSubtitle", "type": "StatusBaseText", "visible": True}
community_welcome_screen_checkList_element1 = {"container": statusDesktop_mainWindow, "objectName": "checkListText_0", "type": "StatusBaseText", "visible": True}
community_welcome_screen_checkList_element2 = {"container": statusDesktop_mainWindow, "objectName": "checkListText_1", "type": "StatusBaseText", "visible": True}
community_welcome_screen_checkList_element3 = {"container": statusDesktop_mainWindow, "objectName": "checkListText_2", "type": "StatusBaseText", "visible": True}
community_welcome_screen_add_new_item = {"container": statusDesktop_mainWindow, "objectName": "addNewItemButton", "type": "StatusButton", "visible": True}

# Permissions view
mainWindow_editPermissionView_EditPermissionView = {"container": mainWindow_Window, "id": "stackLayout", "type": "StackLayout", "unnamed": 1, "visible": True}
mainWindow_editPermissionView_EditPermissionView_2 = {"container": statusDesktop_mainWindow, "id": "editPermissionView", "type": "EditPermissionView", "unnamed": 1, "visible": True}
editPermissionView_Who_holds_StatusItemSelector = {"container": mainWindow_editPermissionView_EditPermissionView, "id": "tokensSelector", "type": "StatusItemSelector", "unnamed": 1, "visible": True}
editPermissionView_Is_allowed_to_StatusFlowSelector = {"container": mainWindow_editPermissionView_EditPermissionView_2, "id": "permissionsSelector", "type": "StatusFlowSelector", "unnamed": 1, "visible": True}
editPermissionView_In_StatusItemSelector = {"container": mainWindow_editPermissionView_EditPermissionView_2, "id": "inSelector", "type": "StatusItemSelector", "unnamed": 1, "visible": True}
editPermissionView_whoHoldsSwitch_StatusSwitch = {"checkable": True, "container": mainWindow_editPermissionView_EditPermissionView, "id": "whoHoldsSwitch", "type": "StatusSwitch", "unnamed": 1, "visible": True}
edit_TextEdit = {"container": statusDesktop_mainWindow_overlay, "type": "TextEdit", "unnamed": 1, "visible": True}
inputValue_StyledTextField = {"container": statusDesktop_mainWindow_overlay, "echoMode": 0, "id": "inputValue", "type": "StatusTextField", "unnamed": 1, "visible": True}
o_TokenItem = {"container": statusDesktop_mainWindow_overlay, "index": 0, "type": "TokenItem", "unnamed": 1, "visible": True}
add_StatusButton = {"checkable": False, "container": statusDesktop_mainWindow_overlay, "type": "StatusButton", "unnamed": 1, "visible": True}
CustomPermissionListItem = {"container": statusDesktop_mainWindow_overlay, "objectName": "becomeAdmin", "type": "CustomPermissionListItem", "visible": True}
communityItem_CommunityListItem = {"container": statusDesktop_mainWindow_overlay, "id": "communityItem", "type": "CommunityListItem", "unnamed": 1, "visible": True}
editPermissionView_switchItem_StatusSwitch = {"checkable": True, "container": mainWindow_editPermissionView_EditPermissionView, "id": "switchItem", "type": "StatusSwitch", "unnamed": 1, "visible": True}
editPermissionView_Create_permission_StatusButton = {"checkable": False, "container": mainWindow_editPermissionView_EditPermissionView, "text": "Create permission", "type": "StatusButton", "unnamed": 1, "visible": True}
mainWindow_PermissionsView = {"container": mainWindow_Window, "type": "PermissionsView", "unnamed": 1, "visible": True}
o_StatusListItemTag = {"container": mainWindow_PermissionsView, "type": "StatusListItemTag", "visible": True}
