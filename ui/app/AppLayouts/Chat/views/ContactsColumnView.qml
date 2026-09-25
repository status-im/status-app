import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups

import utils
import shared
import shared.controls
import shared.popups
import shared.views.chat

import SortFilterProxyModel

import "../panels"
import "../popups"
import AppLayouts.Chat.stores
import AppLayouts.Communities.popups

Item {
    id: root
    width: Constants.chatSectionLeftColumnWidth
    height: parent.height

    // Important:
    // We're here in case of ChatSection
    // This module is set from `ChatLayout` (each `ChatLayout` has its own chatSectionModule)
    property var chatSectionModule

    property RootStore store
    property var emojiPopup

    QtObject {
        id: d

        readonly property int listContentLeftMarginOffset: 1
        readonly property int listContentLeftMargin: SQUtils.Utils.swipeIndicatorWidth + listContentLeftMarginOffset
        readonly property int scrollBarWidth: Math.max(Theme.halfPadding, 8)
        // 1px scrollbar inset and 1px gap before it
        readonly property int scrollBarSpacing: 2
    }

    signal shareOwnProfileRequested()
    signal openAppSearch()
    signal addRemoveGroupMemberClicked()
    signal chatItemClicked(string id)

    // main layout
    ColumnLayout {
        anchors {
            fill: parent
            topMargin: Theme.smallPadding
        }
        spacing: Theme.halfPadding

        // Chat headline row
        MessagesListHeader {
            id: header

            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding

            createChatOpened: root.store.openCreateChat

            onShareOwnProfileRequested: root.shareOwnProfileRequested()
            onStartChatClicked: {
                if (root.store.openCreateChat) {
                    Global.closeCreateChatView()
                } else {
                    Global.openCreateChatView()
                }
            }
        }

        // search field
        SearchBox {
            id: searchInput
            Layout.fillWidth: true
            Layout.leftMargin: Theme.halfPadding
            Layout.rightMargin: d.scrollBarWidth + d.scrollBarSpacing
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            Layout.preferredHeight: 40
            KeyNavigation.tab: channelList
            Keys.onEscapePressed: header.searchChecked = false
            placeholderText: qsTr("Search contacts and groups...")
            visible: header.searchChecked
            onVisibleChanged: {
                clear()
                if (visible) forceActiveFocus()
            }
        }

        // chat list
        StatusChatList {
            id: channelList
            objectName: "ContactsColumnView_chatList"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: d.listContentLeftMargin
            model: SortFilterProxyModel {
                sourceModel: root.chatSectionModule.model
                filters: [
                    SQUtils.SearchFilter {
                        roleName: "name"
                        searchPhrase: searchInput.text
                        enabled: searchInput.visible && !!searchPhrase
                    }
                ]
                sorters: FastExpressionSorter {
                    expectedRoles: ["sortTimestamp", "isThread", "position"]
                    expression: {
                        if (modelLeft.sortTimestamp !== modelRight.sortTimestamp)
                            return modelRight.sortTimestamp - modelLeft.sortTimestamp

                        if (modelLeft.isThread !== modelRight.isThread)
                            return modelLeft.isThread ? 1 : -1

                        return modelLeft.position - modelRight.position
                    }
                }
            }

            highlightItem: !root.store.openCreateChat
            onChatItemSelected: (categoryId, id) => {
                Global.closeCreateChatView()
                root.chatSectionModule.setActiveItem(id)
            }
            onChatItemClicked: (id) => root.chatItemClicked(id)
            onChatItemUnmuted: (id) => root.chatSectionModule.unmuteChat(id)

            popupMenu: ChatContextMenuView {
                id: chatContextMenuView
                showDebugOptions: root.store.isDebugEnabled

                openHandler: function (id) {
                    let jsonObj = root.chatSectionModule.getItemAsJson(id)
                    let obj = JSON.parse(jsonObj)
                    if (obj.error) {
                        console.error("error parsing chat item json object, id: ", id, " error: ", obj.error)
                        close()
                        return
                    }

                    isCommunityChat = root.chatSectionModule.isCommunity()
                    amIChatAdmin = obj.memberRole === Constants.memberRole.owner ||
                            obj.memberRole === Constants.memberRole.admin ||
                            obj.memberRole === Constants.memberRole.tokenMaster
                    chatId = obj.isThread ? obj.parentChatId : obj.itemId
                    chatName = obj.name
                    chatDescription = obj.description
                    chatEmoji = obj.emoji
                    chatColor = obj.color
                    chatIcon = obj.icon
                    chatType = obj.type
                    chatMuted = obj.muted
                    isThread = obj.isThread
                    threadId = obj.isThread ? obj.itemId : ""
                }

                onMuteChat: (chatId, interval) => {
                    root.chatSectionModule.muteChat(chatId, interval)
                }

                onUnmuteChat: (chatId) => {
                    root.chatSectionModule.unmuteChat(chatId)
                }

                onMarkAllMessagesRead: (chatId, threadId) => {
                    root.chatSectionModule.markAllMessagesRead(chatId, threadId)
                }

                onClearChatHistory: (chatId) => {
                    root.chatSectionModule.clearChatHistory(chatId)
                }

                onLeaveChat: (chatId) => {
                    root.chatSectionModule.leaveChat(chatId)
                }

                onDeleteCommunityChat: {
                    // Not Refactored Yet
                }

                onDisplayProfilePopup: (publicKey) => {
                    Global.openProfilePopup(publicKey)
                }

                onUpdateGroupChatDetails: (chatId, groupName, groupColor, groupImage) => {
                    root.chatSectionModule.updateGroupChatDetails(
                                chatId,
                                groupName,
                                groupColor,
                                groupImage
                                )
                }

                onAddRemoveGroupMember: {
                    root.addRemoveGroupMemberClicked()
                }
            }
        }
    }
}
