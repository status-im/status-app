import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Core.Utils as SQUtils

import utils

import shared.views.chat

import "../panels"
import "../stores"

RowLayout {
    id: root

    property alias menuButton: menuButton
    property alias membersButton: membersButton
    property alias searchButton: searchButton

    property RootStore rootStore

    property var mutualContactsModel

    property var chatContentModule: root.rootStore.currentChatContentModule() || null
    property var emojiPopup
    property int padding: Theme.halfPadding

    property var usersModel
    property var amIChatAdmin

    property bool showMembersButtonHighlighted

    signal groupMembersUpdateRequested(string membersPubKeysList)

    signal searchButtonClicked()
    signal displayEditChannelPopup(string chatId,
                                   string chatName,
                                   string chatDescription,
                                   string chatEmoji,
                                   string chatColor,
                                   string chatCategoryId,
                                   int channelPosition,
                                   var deleteDialog,
                                   bool hideIfPermissionsNotMet)

    signal toggleShowMembersRequested

    function addRemoveGroupMember() {
        root.state = d.stateMembersSelectorContent
    }

    onChatContentModuleChanged: {
        // Initialization:
        root.state = d.stateInfoButtonContent
    }

    QtObject {
        id: d

        readonly property string stateInfoButtonContent: ""
        readonly property string stateMembersSelectorContent: "selectingMembers"

        readonly property bool selectingMembers: root.state == stateMembersSelectorContent
    }

    MessageStore {
        id: messageStore
        messageModule: chatContentModule ? chatContentModule.messagesModule : null
        chatSectionModule: root.rootStore.chatCommunitySectionModule
    }

    Loader {
        id: loader

        Layout.fillWidth: true

        sourceComponent: d.selectingMembers ? membersSelector : statusChatInfoButton
    }

    RowLayout {
        id: actionButtons

        Layout.fillHeight: true

        spacing: 8
        visible: !d.selectingMembers

        StatusFlatRoundButton {
            id: searchButton
            icon.name: "search"
            type: StatusFlatRoundButton.Type.Secondary
            onClicked: root.searchButtonClicked()

            // initializing the tooltip
            tooltip.text: qsTr("Search")
            tooltip.orientation: StatusToolTip.Orientation.Bottom
            tooltip.y: parent.height + 12
        }

        StatusFlatRoundButton {
            id: membersButton
            visible: {
                if(!chatContentModule)
                    return false

                return chatContentModule.chatDetails.isUsersListAvailable
            }

            highlighted: root.showMembersButtonHighlighted

            icon.name: "group-chat"
            type: StatusFlatRoundButton.Type.Secondary
            onClicked: root.toggleShowMembersRequested()

            // initializing the tooltip
            tooltip.text: qsTr("Members")
            tooltip.orientation: StatusToolTip.Orientation.Bottom
            tooltip.y: parent.height + 12
        }

        StatusFlatRoundButton {
            id: menuButton
            objectName: "chatToolbarMoreOptionsButton"
            icon.name: "more"
            type: StatusFlatRoundButton.Type.Secondary

            // initializing the tooltip
            tooltip.visible: !!tooltip.text && menuButton.hovered && !contextMenu.opened
            tooltip.text: qsTr("More")
            tooltip.orientation: StatusToolTip.Orientation.Bottom
            tooltip.y: parent.height + 12

            property bool showMoreMenu: false
            onClicked: {
                menuButton.highlighted = true

                let originalOpenHandler = contextMenu.openHandler
                let originalCloseHandler = contextMenu.closeHandler

                contextMenu.openHandler = function () {
                    if (!!originalOpenHandler) {
                        originalOpenHandler()
                    }
                }

                contextMenu.closeHandler = function () {
                    menuButton.highlighted = false
                    if (!!originalCloseHandler) {
                        originalCloseHandler()
                    }
                }

                contextMenu.openHandler = originalOpenHandler
                contextMenu.popup(-contextMenu.width + menuButton.width, menuButton.height + 4)
            }

            ChatContextMenuView {
                id: contextMenu
                objectName: "moreOptionsContextMenu"
                showDebugOptions: root.rootStore.isDebugEnabled
                openHandler: function () {
                    if(!chatContentModule) {
                        console.debug("error on open chat context menu handler - chat content module is not set")
                        return
                    }
                    isCommunityChat = chatContentModule.chatDetails.belongsToCommunity
                    amIChatAdmin = chatContentModule.amIChatAdmin()
                    chatId = chatContentModule.chatDetails.id
                    chatName = chatContentModule.chatDetails.name
                    chatDescription = chatContentModule.chatDetails.description
                    chatEmoji = chatContentModule.chatDetails.emoji
                    chatColor = chatContentModule.chatDetails.color
                    chatIcon = chatContentModule.chatDetails.icon
                    chatType = chatContentModule.chatDetails.type
                    chatMuted = chatContentModule.chatDetails.muted
                    channelPosition = chatContentModule.chatDetails.position
                    hideIfPermissionsNotMet = chatContentModule.chatDetails.hideIfPermissionsNotMet
                }

                onMuteChat: {
                    if(!chatContentModule) {
                        console.debug("error on mute chat from context menu - chat content module is not set")
                        return
                    }
                    chatContentModule.muteChat(interval)
                }

                onUnmuteChat: {
                    if(!chatContentModule) {
                        console.debug("error on unmute chat from context menu - chat content module is not set")
                        return
                    }
                    chatContentModule.unmuteChat()
                }

                onMarkAllMessagesRead: {
                    if(!chatContentModule) {
                        console.debug("error on mark all messages read from context menu - chat content module is not set")
                        return
                    }
                    chatContentModule.markAllMessagesRead()
                }

                onClearChatHistory: {
                    if(!chatContentModule) {
                        console.debug("error on clear chat history from context menu - chat content module is not set")
                        return
                    }
                    chatContentModule.clearChatHistory()
                }

                onLeaveChat: {
                    if(!chatContentModule) {
                        console.debug("error on leave chat from context menu - chat content module is not set")
                        return
                    }
                    chatContentModule.leaveChat()
                }

                onDeleteCommunityChat: root.rootStore.removeCommunityChat(chatId)

                onDisplayProfilePopup: {
                    Global.openProfilePopup(publicKey)
                }
                onDisplayEditChannelPopup: {
                    root.displayEditChannelPopup(chatId, chatName, chatDescription,
                                                 chatEmoji, chatColor,
                                                 chatCategoryId, channelPosition,
                                                 contextMenu.deleteChatConfirmationDialog,
                                                 hideIfPermissionsNotMet);
                }
                onAddRemoveGroupMember: {
                    root.addRemoveGroupMember()
                }
                onUpdateGroupChatDetails: {
                    root.rootStore.chatCommunitySectionModule.updateGroupChatDetails(
                                chatId,
                                groupName,
                                groupColor,
                                groupImage
                                )
                }
            }
        }
    }

    // Chat toolbar content option 1:
    Component {
        id: statusChatInfoButton

        StatusChatInfoButton {
            readonly property string emojiIcon: chatContentModule? chatContentModule.chatDetails.emoji : "" // Needed for test
            readonly property string assetName: chatContentModule && chatContentModule.chatDetails.icon

            objectName: "chatInfoBtnInHeader"
            title: chatContentModule? chatContentModule.chatDetails.name : ""
            requiresPermissions: chatContentModule ? chatContentModule.chatDetails.requiresPermissions : false
            locked: requiresPermissions && (chatContentModule ? !chatContentModule.chatDetails.canPost : false)
            subTitle: {
                if(!chatContentModule)
                    return ""

                // In some moment in future this should be part of the backend logic.
                // (once we add translation on the backend side)
                switch (chatContentModule.chatDetails.type) {
                case Constants.chatType.privateGroupChat:
                    return qsTr("%n member(s)", "", chatContentModule.usersModule.model.count)
                case Constants.chatType.communityChat:
                    return SQUtils.Utils.linkifyAndXSS(chatContentModule.chatDetails.description).trim()
                default:
                    return ""
                }
            }
            asset.name: assetName
            asset.isImage: chatContentModule && chatContentModule.chatDetails.icon !== ""
            asset.isLetterIdenticon: chatContentModule && chatContentModule.chatDetails.icon === ""
            asset.color: chatContentModule?
                            chatContentModule.chatDetails.type === Constants.chatType.oneToOne ?
                                Utils.colorForPubkey(Theme.palette, chatContentModule.chatDetails.id)
                              : chatContentModule.chatDetails.color
            : ""
            asset.emoji: emojiIcon
            asset.emojiSize: "24x24"
            type: chatContentModule ? chatContentModule.chatDetails.type : Constants.chatType.unknown
            pinnedMessagesCount: chatContentModule? chatContentModule.pinnedMessagesModel.count : 0
            muted: chatContentModule? chatContentModule.chatDetails.muted : false

            onPinnedMessagesCountClicked: {
                if(!chatContentModule) {
                    console.warn("error on open pinned messages - chat content module is not set")
                    return
                }
                const chatId = type === Constants.chatType.oneToOne ? chatContentModule.getMyChatId() : ""
                Global.openPinnedMessagesPopupRequested(rootStore, messageStore, chatContentModule.pinnedMessagesModel, "", chatId)
            }
            onUnmute: {
                if(!chatContentModule) {
                    console.debug("error on unmute chat - chat content module is not set")
                    return
                }
                chatContentModule.unmuteChat()
            }

            hoverEnabled: {
                if(!chatContentModule)
                    return false

                return chatContentModule.chatDetails.type !== Constants.chatType.communityChat &&
                        chatContentModule.chatDetails.type !== Constants.chatType.privateGroupChat
            }
            onClicked: {
                switch (chatContentModule.chatDetails.type) {
                case Constants.chatType.oneToOne:
                    Global.openProfilePopup(chatContentModule.chatDetails.id)
                    break;
                }
            }
            onLinkActivated: (link) => Global.requestOpenLink(link)
        }
    }

    // Chat toolbar content option 2:
    Component {
        id: membersSelector

        MembersEditSelectorView {
            contactsModel: root.mutualContactsModel
            usersModel: root.usersModel

            amIChatAdmin: root.amIChatAdmin

            onConfirmed: root.state = d.stateInfoButtonContent
            onRejected: root.state = d.stateInfoButtonContent

            onGroupMembersUpdateRequested: root.groupMembersUpdateRequested(membersPubKeysList)
        }
    }
}
