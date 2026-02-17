import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups

import utils
import shared
import shared.controls
import shared.popups
import shared.views.chat
import shared.panels

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

    signal shareOwnProfileRequested()
    signal openAppSearch()
    signal addRemoveGroupMemberClicked()
    signal chatItemClicked(string id)

    component HeaderButton: StatusFlatButton {
        icon.color: hovered || checked ? Theme.palette.primaryColor1 : Theme.palette.directColor1
        isRoundIcon: true
        tooltip.orientation: StatusToolTip.Orientation.Bottom
    }

    // main layout
    ColumnLayout {
        anchors {
            fill: parent
            topMargin: Theme.smallPadding
        }
        spacing: Theme.halfPadding

        // Chat headline row
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding

            StatusNavigationPanelHeadline {
                objectName: "ContactsColumnView_MessagesHeadline"
                text: qsTr("Messages")
            }

            Item {
                Layout.fillWidth: true
            }

            HeaderButton {
                objectName: "shareProfileButton"
                icon.name: "add-contact"
                tooltip.text: qsTr("Invite contacts")
                onClicked: root.shareOwnProfileRequested()
            }

            HeaderButton {
                objectName: "qrScannerButton"
                icon.name: "qr-scan"
                tooltip.text: qsTr("Open QR Scanner")
                onClicked: Global.openQRScannerRequested()
            }

            HeaderButton {
                objectName: "startChatButton"
                icon.name: "edit"
                checkable: true
                checked: root.store.openCreateChat
                tooltip.text: qsTr("Start chat")
                onClicked: {
                    if (root.store.openCreateChat) {
                        Global.closeCreateChatView()
                    } else {
                        Global.openCreateChatView()
                    }
                }
            }
        }

        // search field
        SearchBox {
            id: searchInput
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding
            Layout.preferredHeight: 40
            input.topPadding: 4
            input.bottomPadding: 4
            StatusMouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openAppSearch()
            }
        }

        ChatsLoadingPanel {
            Layout.fillWidth: true
            chatSectionModule: root.chatSectionModule
        }

        // chat list
        StatusScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth

            StatusChatList {
                id: channelList
                objectName: "ContactsColumnView_chatList"
                width: scrollView.availableWidth
                model: SortFilterProxyModel {
                    sourceModel: root.chatSectionModule.model
                    sorters: RoleSorter {
                        roleName: "lastMessageTimestamp"
                        sortOrder: Qt.DescendingOrder
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
                        chatId = obj.itemId
                        chatName = obj.name
                        chatDescription = obj.description
                        chatEmoji = obj.emoji
                        chatColor = obj.color
                        chatIcon = obj.icon
                        chatType = obj.type
                        chatMuted = obj.muted
                    }

                    onMuteChat: {
                        root.chatSectionModule.muteChat(chatId, interval)
                    }

                    onUnmuteChat: {
                        root.chatSectionModule.unmuteChat(chatId)
                    }

                    onMarkAllMessagesRead: {
                        root.chatSectionModule.markAllMessagesRead(chatId)
                    }

                    onClearChatHistory: {
                        root.chatSectionModule.clearChatHistory(chatId)
                    }

                    onLeaveChat: {
                        root.chatSectionModule.leaveChat(chatId)
                    }

                    onDeleteCommunityChat: {
                        // Not Refactored Yet
                    }

                    onDisplayProfilePopup: {
                        Global.openProfilePopup(publicKey)
                    }

                    onUpdateGroupChatDetails: {
                        chatSectionModule.updateGroupChatDetails(
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
}
