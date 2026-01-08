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

    signal openProfileClicked()
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
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padding
            Layout.rightMargin: Theme.padding

            StatusNavigationPanelHeadline {
                objectName: "ContactsColumnView_MessagesHeadline"
                Layout.alignment: Qt.AlignVCenter
                text: qsTr("Messages")
            }

            Item {
                Layout.fillWidth: true
            }

            StatusIconTabButton {
                id: qrScannerButton
                Layout.alignment: Qt.AlignVCenter
                objectName: "qrScannerButton"
                icon.name: "qr-scan"
                icon.color: Theme.palette.directColor1
                onClicked: Global.openQRScannerRequested()

                StatusToolTip {
                    text: qsTr("Open QR Scanner")
                    visible: parent.hovered
                    orientation: StatusToolTip.Orientation.Bottom
                    y: parent.height + 12
                }
            }

            StatusIconTabButton {
                id: startChatButton
                Layout.alignment: Qt.AlignVCenter
                objectName: "startChatButton"
                icon.name: "edit"
                icon.color: Theme.palette.directColor1
                checked: root.store.openCreateChat
                highlighted: checked
                onClicked: {
                    if (root.store.openCreateChat) {
                        Global.closeCreateChatView()
                    } else {
                        Global.openCreateChatView()
                    }
                }

                StatusToolTip {
                    text: qsTr("Start chat")
                    visible: parent.hovered
                    orientation: StatusToolTip.Orientation.Bottom
                    y: parent.height + 12
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
                onChatItemSelected: {
                    Global.closeCreateChatView()
                    root.chatSectionModule.setActiveItem(id, "")
                }
                onChatItemClicked: (id) => {
                    root.chatItemClicked(id)
                }
                onChatItemUnmuted: root.chatSectionModule.unmuteChat(id)

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

                    onRequestMoreMessages: {
                        root.chatSectionModule.requestMoreMessages(chatId)
                    }

                    onClearChatHistory: {
                        root.chatSectionModule.clearChatHistory(chatId)
                    }

                    onRequestAllHistoricMessages: {
                        // Not Refactored Yet - Check in the `master` branch if this is applicable here.
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
