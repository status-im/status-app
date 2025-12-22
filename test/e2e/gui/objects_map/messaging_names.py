from gui.objects_map.names import statusDesktop_mainWindow

# Map for messaging screens, views locators

mainWindow_chatView_ChatView = {"container": statusDesktop_mainWindow, "objectName": "chatViewComponent", "type": "ChatView", "visible": True}

# Left Panel
mainWindow_contactColumnLoader_Loader = {"container": mainWindow_chatView_ChatView, "id": "contactColumnLoader", "type": "Loader", "unnamed": 1, "visible": True}
mainWindow_startChatButton_StatusIconTabButton = {"checkable": True, "container": mainWindow_contactColumnLoader_Loader, "objectName": "startChatButton", "type": "StatusIconTabButton", "visible": True}
mainWindow_search_edit_TextEdit = {"container": mainWindow_contactColumnLoader_Loader, "id": "edit", "type": "TextEdit", "unnamed": 1, "visible": True}
mainWindow_scrollView_StatusScrollView = {"container": mainWindow_contactColumnLoader_Loader, "id": "scrollView", "type": "StatusScrollView", "unnamed": 1, "visible": True}
scrollView_Flickable = {"container": mainWindow_scrollView_StatusScrollView, "type": "Flickable", "unnamed": 1, "visible": True}
scrollView_ContactsColumnView_chatList_StatusChatList = {"container": mainWindow_scrollView_StatusScrollView, "objectName": "ContactsColumnView_chatList", "type": "StatusChatList", "visible": True}
chatList_ListView = {"container": statusDesktop_mainWindow, "objectName": "chatListItems", "type": "StatusListView", "visible": True}

# Tool Bar
mainWindow_statusToolBar_StatusToolBar = {"container": mainWindow_chatView_ChatView, "objectName": "statusToolBar", "type": "StatusToolBar", "visible": True}
statusToolBar_Confirm_StatusButton = {"checkable": False, "container": mainWindow_statusToolBar_StatusToolBar, "objectName": "inlineSelectorConfirmButton", "type": "StatusButton", "visible": True}
statusToolBar_Cancel_StatusButton = {"checkable": False, "container": mainWindow_statusToolBar_StatusToolBar, "type": "StatusButton", "unnamed": 1, "visible": True}
statusToolBar_StatusTagItem = {"container": mainWindow_statusToolBar_StatusToolBar, "type": "StatusTagItem", "visible": True}

# Chat View
mainWindow_ChatColumnView = {"container": mainWindow_chatView_ChatView, "type": "ChatColumnView", "unnamed": 1, "visible": True}
mainWindow_chatLogView_StatusListView = {"container": mainWindow_ChatColumnView, "objectName": "chatLogView", "type": "StatusListView", "visible": True}
chatLogView_chatMessageViewDelegate_MessageView = {"container": mainWindow_chatLogView_StatusListView, "objectName": "chatMessageViewDelegate", "type": "MessageView", "visible": True, "enabled": True}

# Create Chat View
mainWindow_CreateChatView = {"container": statusDesktop_mainWindow, "type": "CreateChatView", "unnamed": 1, "visible": True}
createChatView_confirmBtn = {"container": statusDesktop_mainWindow, "objectName": "inlineSelectorConfirmButton", "type": "StatusButton"}
createChatView_contactsList = {"container": statusDesktop_mainWindow, "objectName": "createChatContactsList", "type": "StatusListView", "visible": True}
mainWindow_Cancel_StatusButton = {"checkable": False, "container": statusDesktop_mainWindow, "text": "Cancel", "type": "StatusButton", "unnamed": 1, "visible": True}

# Chat Messages View
mainWindow_ChatMessagesView = {"container": statusDesktop_mainWindow, "type": "ChatMessagesView", "unnamed": 1, "visible": True}
chatView_log = {"container": statusDesktop_mainWindow, "objectName": "chatLogView", "type": "StatusListView", "visible": True}
groupchatLogView_chatMessageViewDelegate_MessageView = {"container": chatView_log, "objectName": "chatMessageViewDelegate", "type": "MessageView", "visible": True}
groupMessagesItem = {"container": groupchatLogView_chatMessageViewDelegate_MessageView, "type": "StatusBaseText", "unnamed": 1, "visible": True}
chatMessageViewDelegate_ChannelIdentifierView = {"container": chatLogView_chatMessageViewDelegate_MessageView, "type": "ChannelIdentifierView", "unnamed": 1, "visible": True}
chatLogView_Item = {"container": chatView_log, "type": "Item", "unnamed": 1, "visible": True}
statusChatInfoButton = {"container": mainWindow_statusToolBar_StatusToolBar, "objectName": "statusChatInfoButtonNameText", "type": "TruncatedTextWithTooltip", "visible": True}
moreOptionsButton_StatusFlatRoundButton = {"container": mainWindow_statusToolBar_StatusToolBar, "objectName": "chatToolbarMoreOptionsButton", "type": "StatusFlatRoundButton", "visible": True}
mainWindow_Overlay = {"container": statusDesktop_mainWindow, "type": "Overlay", "unnamed": 1, "visible": True}
edit_name_and_image_StatusMenuItem = {"checkable": False, "container": mainWindow_Overlay, "enabled": True, "objectName": "editNameAndImageMenuItem", "text": "Edit name and image", "type": "StatusMenuItem", "visible": True}
leave_group_StatusMenuItem = {"checkable": False, "container": mainWindow_Overlay, "enabled": True, "objectName": "deleteOrLeaveMenuItem", "text": "Leave group", "type": "StatusMenuItem", "visible": True}
mainWindow_inputScrollView_StatusScrollView = {"container": statusDesktop_mainWindow, "id": "inputScrollView", "type": "StatusScrollView", "unnamed": 1, "visible": True}
inputScrollView_Message_PlaceholderText = {"container": mainWindow_inputScrollView_StatusScrollView, "text": "Message", "type": "PlaceholderText", "unnamed": 1, "visible": True}
mainWindow_scrollView_StatusScrollView = {"container": statusDesktop_mainWindow, "id": "scrollView", "type": "StatusScrollView", "unnamed": 1, "visible": True}
mainWindow_ScrollView = {"container": statusDesktop_mainWindow, "type": "StatusScrollView", "unnamed": 1, "visible": True}
scrollView_StatusChatListItem = {"container": mainWindow_ScrollView, "type": "StatusChatListItem", "visible": True}
tiny_pin_icon_StatusIcon = {"container": chatLogView_chatMessageViewDelegate_MessageView, "objectName": "tiny/pin-icon", "type": "StatusIcon"}
add_remove_from_group_StatusMenuItem = {"container": mainWindow_Overlay, "enabled": True, "objectName": "addRemoveFromGroupStatusAction", "type": "StatusMenuItem", "visible": True}
mainWindow_inputScrollView_StatusScrollView = {"container": statusDesktop_mainWindow, "id": "inputScrollView", "type": "StatusScrollView", "unnamed": 1, "visible": True}
inputScrollView_messageInputField_TextArea = {"container": mainWindow_inputScrollView_StatusScrollView, "objectName": "messageInputField", "type": "TextArea", "visible": True}
mainWindow_statusChatInputEmojiButton_StatusFlatRoundButton = {"container": statusDesktop_mainWindow, "objectName": "statusChatInputEmojiButton", "type": "StatusFlatRoundButton", "visible": True}
mainWindow_imageBtn_StatusFlatRoundButton = {"container": statusDesktop_mainWindow, "id": "imageBtn", "type": "StatusFlatRoundButton", "unnamed": 1, "visible": True}
mainWindow_statusChatInput_StatusChatInput = {"container": statusDesktop_mainWindow, "objectName": "statusChatInput", "type": "Rectangle", "visible": True}
mark_as_Read_StatusMenuItem = {"checkable": False, "container": mainWindow_Overlay, "enabled": True, "objectName": "chatMarkAsReadMenuItem", "type": "StatusMenuItem", "visible": True}
clear_History_StatusMenuItem = {"checkable": False, "container": mainWindow_Overlay, "enabled": True, "objectName": "clearHistoryMenuItem", "type": "StatusMenuItem", "visible": True}
clear_group_chat_history_item = {"checkable": False, "container": mainWindow_Overlay, "enabled": True, "objectName": "clearHistoryGroupMenuItem", "type": "StatusMenuItem", "visible": True}
close_Chat_StatusMenuItem = {"checkable": False, "container": mainWindow_Overlay, "enabled": True, "objectName": "deleteOrLeaveMenuItem", "type": "StatusMenuItem", "visible": True}
o_EmojiReaction = {"container": mainWindow_Overlay, "type": "EmojiReaction", "unnamed": 1, "visible": True}
chatMessageViewDelegate_StatusEmoji = {"container": chatLogView_chatMessageViewDelegate_MessageView, "objectName": "emojiReaction", "type": "StatusEmoji", "unnamed": 1, "visible": True}
messageContextView = {"container": mainWindow_Overlay, "objectName": "MessageContextMenuView", "type": "PopupItem", "visible": True}

# User List Panel
mainWindow_UserListPanel = {"container": mainWindow_chatView_ChatView, "type": "UserListPanel", "unnamed": 1, "visible": True}
userListPanel_StatusMemberListItem = {"container": mainWindow_UserListPanel, "type": "StatusMemberListItem", "unnamed": 1, "visible": True}

# Group chat users list panel
mainWindow_userListPanel_StatusListView = {"container": statusDesktop_mainWindow, "objectName": "userListPanel", "type": "StatusListView", "visible": True}
groupUserListPanel_StatusMemberListItem = {"container": mainWindow_userListPanel_StatusListView, "type": "StatusMemberListItem", "unnamed": 1, "visible": True}

# Message quick actions
mainWindow_chatLogView_StatusListView = {"container":  statusDesktop_mainWindow, "objectName": "chatLogView", "type": "StatusListView", "visible": True}
chatLogView_chatMessageViewDelegate_MessageView = {"container": mainWindow_chatLogView_StatusListView, "objectName": "chatMessageViewDelegate", "type": "MessageView", "visible": True}
StatusTextMessage_chatTextMessage = {"container": chatLogView_chatMessageViewDelegate_MessageView, "objectName": "StatusTextMessage_chatText", "type": "TextEdit", "visible": True}

chatMessageViewDelegate_deletedMessage_RowLayout = {"container": chatLogView_chatMessageViewDelegate_MessageView, "id": "deletedMessage", "type": "RowLayout", "unnamed": 1, "visible": True}
chatMessageViewDelegate_StatusMessageQuickActions = {"container": chatLogView_chatMessageViewDelegate_MessageView, "type": "StatusMessageQuickActions", "unnamed": 1, "visible": True}
chatMessageViewDelegate_pin_icon_StatusIcon = {"container": chatLogView_chatMessageViewDelegate_MessageView, "objectName": "pin-icon", "type": "StatusIcon", "visible": True}
chatMessageViewDelegate_unpin_icon_StatusIcon = {"container": chatLogView_chatMessageViewDelegate_MessageView, "objectName": "unpin-icon", "type": "StatusIcon", "visible": True}
chatMessageViewDelegate_editMessageButton_StatusFlatRoundButton = {"container": chatLogView_chatMessageViewDelegate_MessageView, "objectName": "editMessageButton", "type": "StatusFlatRoundButton", "visible": True}
chatMessageViewDelegate_markAsUnreadButton_StatusFlatRoundButton = {"container": chatLogView_chatMessageViewDelegate_MessageView, "objectName": "markAsUnreadButton", "type": "StatusFlatRoundButton", "visible": True}
chatMessageViewDelegate_chatDeleteMessageButton_StatusFlatRoundButton = {"container": chatLogView_chatMessageViewDelegate_MessageView, "objectName": "chatDeleteMessageButton", "type": "StatusFlatRoundButton", "visible": True}
chatMessageViewDelegate_inputScrollView_StatusScrollView = {"container": chatLogView_chatMessageViewDelegate_MessageView, "id": "inputScrollView", "type": "StatusScrollView", "unnamed": 1, "visible": True}
edit_inputScrollView_messageInputField_TextArea = {"container": chatMessageViewDelegate_inputScrollView_StatusScrollView, "objectName": "messageInputField", "type": "TextArea", "visible": True}
chatMessageViewDelegate_Save_StatusButton = {"checkable": False, "container": chatLogView_chatMessageViewDelegate_MessageView, "id": "saveBtn", "type": "StatusButton", "unnamed": 1, "visible": True}
chatMessageViewDelegate_reply_icon_StatusIcon = {"container": chatLogView_chatMessageViewDelegate_MessageView, "objectName": "reply-icon", "type": "StatusIcon", "visible": True}
mainWindow_replyArea_StatusChatInputReplyArea = {"container": statusDesktop_mainWindow, "id": "replyArea", "type": "StatusChatInputReplyArea", "unnamed": 1, "visible": True}
layout_recentMessagesButton_AnchorButton = {"checkable": False, "container": mainWindow_chatLogView_StatusListView, "id": "recentMessagesButton", "type": "AnchorButton", "unnamed": 1, "visible": True}

# Message link preview
mainWindow_optionsComboBox_ComboBox = {"container": statusDesktop_mainWindow, "id": "optionsComboBox", "type": "ComboBox", "unnamed": 1, "visible": True}
mainWindow_settingsCard_LinkPreviewSettingsCard = {"container": statusDesktop_mainWindow, "id": "settingsCard", "type": "LinkPreviewSettingsCard", "unnamed": 1, "visible": True}
mainWindow_closeLinkPreviewButton_StatusFlatRoundButton = {"container": statusDesktop_mainWindow, "objectName": "closeLinkPreviewButton", "type": "StatusFlatRoundButton", "visible": True}
mainWindow_linkPreviewTitleText_StatusBaseText = {"container":  statusDesktop_mainWindow, "objectName": "linkPreviewTitleText", "type": "StatusBaseText", "visible": True}
mainWindow_linkPreviewSubtitleText_StatusBaseText = {"container": statusDesktop_mainWindow, "objectName": "linkPreviewSubtitleText", "type": "StatusBaseText", "visible": True}
mainWindow_titleText_StatusBaseText = {"container": statusDesktop_mainWindow, "objectName": "titleText", "type": "StatusBaseText", "visible": True}
mainWindow_subtitleText_StatusBaseText = {"container": statusDesktop_mainWindow, "objectName": "subtitleText", "type": "StatusBaseText", "visible": True}
linkPreviewTitle_StatusBaseText = {"container": chatLogView_chatMessageViewDelegate_MessageView, "objectName": "linkPreviewTitle", "type": "StatusBaseText", "visible": True}
linkPreviewEmojiHash_EmojiHash = {"container": chatLogView_chatMessageViewDelegate_MessageView, "objectName": "linkPreviewEmojiHash", "type": "EmojiHash", "visible": True}
