import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Popups
import StatusQ.Popups.Dialog

import AppLayouts.Communities.popups
import shared.controls.chat.menuItems
import shared.popups
import utils

StatusMenu {
    id: root

    property bool isCommunityChat: false
    property bool amIChatAdmin: false
    property string chatId: ""
    property string chatName: ""
    property string chatDescription: ""
    property string chatEmoji: ""
    property string chatColor: ""
    property string chatIcon: ""
    property int chatType: -1
    property bool chatMuted: false
    property int channelPosition: -1
    property string chatCategoryId: ""
    property bool viewersCanPostReactions: true
    property bool showDebugOptions: false
    property alias deleteChatConfirmationDialog: deleteChatConfirmationDialogComponent
    property bool hideIfPermissionsNotMet: false

    signal displayProfilePopup(string publicKey)
    signal displayEditChannelPopup(string chatId)
    signal unmuteChat(string chatId)
    signal muteChat(string chatId, int interval)
    signal markAllMessagesRead(string chatId)
    signal clearChatHistory(string chatId)
    signal deleteCommunityChat(string chatId)
    signal leaveChat(string chatId)
    signal updateGroupChatDetails(string chatId, string groupName, string groupColor, string groupImage)

    signal addRemoveGroupMember()

    width: root.amIChatAdmin && (root.chatType === Constants.chatType.privateGroupChat) ? 207 : implicitWidth

    ViewProfileMenuItem {
        enabled: root.chatType === Constants.chatType.oneToOne
        onTriggered: root.displayProfilePopup(root.chatId)
    }

    StatusAction {
        objectName: "addRemoveFromGroupStatusAction"
        text: root.amIChatAdmin ? qsTr("Add / remove from group") : qsTr("Add to group")
        icon.name: "add-to-dm"
        enabled: (root.chatType === Constants.chatType.privateGroupChat)
        onTriggered: { root.addRemoveGroupMember() }
    }

    StatusAction {
        objectName: "copyChannelLinkStatusAction"
        text: qsTr("Copy channel link")
        icon.name: "copy"
        enabled: root.isCommunityChat
        onTriggered: {
            const link = Utils.getCommunityChannelShareLinkWithChatId(root.chatId)
            ClipboardUtils.setText(link)
        }
    }

    StatusMenuSeparator {
        visible: root.chatType === Constants.chatType.oneToOne || root.chatType === Constants.chatType.privateGroupChat || root.isCommunityChat
    }

    StatusAction {
        objectName: "editNameAndImageMenuItem"
        text: qsTr("Edit name and image")
        icon.name: "edit_pencil"
        enabled: root.chatType === Constants.chatType.privateGroupChat
        onTriggered: {
            Global.openPopup(renameGroupPopupComponent, {
                activeGroupName: root.chatName,
                activeGroupColor: root.chatColor,
                activeGroupImageData: root.chatIcon
            });
        }
    }

    Component {
        id: renameGroupPopupComponent
        RenameGroupPopup {
            destroyOnClose: true
            onUpdateGroupChatDetails: {
                root.updateGroupChatDetails(root.chatId, groupName, groupColor, groupImage)
                close()
            }
        }
    }

    MuteChatMenuItem {
        enabled: !root.chatMuted
        isCommunityChat: root.isCommunityChat

        onMuteTriggered: {
            root.muteChat(root.chatId, interval)
        }
    }

    StatusAction {
        objectName: "muteChatStatusAction"
        enabled: root.chatMuted
        text: root.isCommunityChat ? qsTr("Unmute Channel") : qsTr("Unmute Chat")
        icon.name: "notification"
        onTriggered: {
            root.unmuteChat(root.chatId)
        }
    }

    StatusAction {
        objectName: "chatMarkAsReadMenuItem"
        text: qsTr("Mark as Read")
        icon.name: "checkmark-circle"
        onTriggered: {
            root.markAllMessagesRead(root.chatId)
        }
    }

    StatusAction {
        objectName: "editChannelMenuItem"
        text: qsTr("Edit Channel")
        icon.name: "edit"
        enabled: root.isCommunityChat && root.amIChatAdmin
        onTriggered: {
            root.displayEditChannelPopup(root.chatId);
        }
    }

    StatusMenu {
        title: qsTr("Debug actions")
        enabled: root.showDebugOptions

        StatusAction {
            text: root.isCommunityChat ? qsTr("Copy channel ID") : qsTr("Copy chat ID")
            icon.name: "copy"
            onTriggered: ClipboardUtils.setText(root.chatId)
        }
    }

    StatusMenuSeparator {
        visible: clearHistoryGroupMenuItem.enabled || deleteOrLeaveMenuItem.enabled
    }

    StatusAction {
        id: clearHistoryGroupMenuItem
        objectName: "clearHistoryGroupMenuItem"
        enabled: (root.chatType !== Constants.chatType.oneToOne)
        text: qsTr("Clear History")
        icon.name: "delete"
        type: StatusAction.Type.Danger
        onTriggered: {
            Global.openPopup(clearChatConfirmationDialogComponent);
        }
    }

    StatusAction {
        id: deleteOrLeaveMenuItem
        objectName: "deleteOrLeaveMenuItem"
        text: {
            if (root.isCommunityChat) {
                return qsTr("Delete Channel")
            }
            if (root.chatType === Constants.chatType.privateGroupChat) {
                return qsTr("Leave group")
            }
            return root.chatType === Constants.chatType.oneToOne ?
                        qsTr("Close Chat") :
                        qsTr("Leave Chat")
        }
        icon.name: root.chatType === Constants.chatType.oneToOne || root.isCommunityChat ? "close-circle" : "arrow-left"
        icon.width: root.chatType === Constants.chatType.oneToOne || root.isCommunityChat ? 18 : 14

        type: StatusAction.Type.Danger
        onTriggered: {
            if (root.chatType === Constants.chatType.privateGroupChat) {
                Global.openPopup(leaveGroupConfirmationDialogComponent);
            } else {
                Global.openPopup(deleteChatConfirmationDialogComponent);
            }
        }

        enabled: !root.isCommunityChat || root.amIChatAdmin
    }

    StatusAction {
        id: clearHistoryMenuItem
        objectName: "clearHistoryMenuItem"
        enabled: (root.chatType === Constants.chatType.oneToOne)
        text: qsTr("Clear History")
        icon.name: "delete"
        type: StatusAction.Type.Danger
        onTriggered: {
            Global.openPopup(clearChatConfirmationDialogComponent);
        }
    }

    Component {
        id: clearChatConfirmationDialogComponent
        ConfirmationDialog {
            confirmButtonObjectName: "clearChatConfirmationDialogClearButton"
            headerSettings.title: qsTr("Clear chat history")
            confirmationText: qsTr("Are you sure you want to clear your chat history with <b>%1</b>? All messages will be deleted on your side and will be unrecoverable.").arg(root.chatName)
            confirmButtonLabel: qsTr("Clear chat history")
            showCancelButton: true
            cancelBtnType: "normal"

            onClosed: {
                destroy()
            }
            onCancelButtonClicked: {
                close()
            }
            onConfirmButtonClicked: {
                root.clearChatHistory(root.chatId)
                close()
            }
        }
    }

    Component {
        id: leaveGroupConfirmationDialogComponent
        ConfirmationDialog {
            confirmButtonObjectName: "leaveGroupConfirmationDialogLeaveButton"
            headerSettings.title: qsTr("Leave group")
            confirmationText: qsTr("Are you sure you want to leave group chat <b>%1</b>?").arg(root.chatName)
            confirmButtonLabel: qsTr("Leave")
            showCancelButton: true
            cancelBtnType: "normal"

            onClosed: {
                destroy()
            }
            onCancelButtonClicked: {
                close()
            }
            onConfirmButtonClicked: {
                root.leaveChat(root.chatId)
                close()
            }
        }
    }

    Component {
        id: deleteChatConfirmationDialogComponent
        ConfirmationDialog {
            confirmButtonObjectName: "deleteChatConfirmationDialogDeleteButton"
            headerSettings.title: root.isCommunityChat ? qsTr("Delete #%1").arg(root.chatName) :
                                            root.chatType === Constants.chatType.oneToOne ?
                                            qsTr("Close chat") :
                                            qsTr("Leave chat")
            confirmButtonLabel: root.isCommunityChat ? qsTr("Delete") : headerSettings.title
            confirmationText: root.isCommunityChat ? qsTr("Are you sure you want to delete #%1 channel?").arg(root.chatName) :
                                                root.chatType === Constants.chatType.oneToOne ?
                                                qsTr("Are you sure you want to close this chat? This will remove the chat from the list. Your chat history will be retained and shown the next time you message each other."):
                                                qsTr("Are you sure you want to leave this chat?")
            showCancelButton: true
            cancelBtnType: "normal"

            onClosed: {
                destroy()
            }
            onCancelButtonClicked: {
                close()
            }
            onConfirmButtonClicked: {
                if(root.isCommunityChat)
                    root.deleteCommunityChat(root.chatId)
                else
                    root.leaveChat(root.chatId)

                close()
            }
        }
    }
}
