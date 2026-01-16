import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Components

import utils
import shared.controls.chat

StatusMenu {
    id: root

    property var emojiModel

    property string myPublicKey: ""
    property bool amIChatAdmin: false
    property bool disabledForChat: false
    property bool forceEnableEmojiReactions: false

    property int chatType: Constants.chatType.unknown
    property string messageId: ""
    property string unparsedText: ""
    property string messageSenderId: ""
    property int messageContentType: Constants.messageContentType.unknownContentType

    property bool pinMessageAllowedForMembers: false
    property bool isDebugEnabled: false
    property bool editRestricted: false
    property bool pinnedMessage: false
    property bool canPin: false
    property bool emojiReactionLimitReached: false

    readonly property bool isMyMessage: {
        return root.messageSenderId !== "" && root.messageSenderId === root.myPublicKey;
    }

    signal pinMessage()
    signal unpinMessage()
    signal pinnedMessagesLimitReached()
    signal showReplyArea(string messageSenderId)
    signal toggleReaction(string hexcode)
    signal deleteMessage()
    signal editClicked()
    signal markMessageAsUnread()
    signal copyToClipboard(string text)
    signal openEmojiPopup(var parent, var mouse)

    MessageReactionsRow {
        id: emojiRow
        visible: !root.emojiReactionLimitReached && (!root.disabledForChat || root.forceEnableEmojiReactions)
        emojiModel: root.emojiModel
        onToggleReaction: hexcode => {
            root.toggleReaction(hexcode)
            root.close()
        }
        onOpenEmojiPopup: (parent, mouse) => {
            root.openEmojiPopup(parent, mouse)
            root.close()
        }
    }

    StatusMenuSeparator {
        visible: emojiRow.visible && !root.disabledForChat
        horizontalPadding: 0
    }

    StatusAction {
        id: replyToMenuItem
        text: qsTr("Reply to")
        icon.name: "chat"
        onTriggered: root.showReplyArea(root.messageSenderId)
        enabled: !root.disabledForChat
    }

    StatusAction {
        id: editMessageAction
        text: qsTr("Edit message")
        onTriggered: editClicked()
        icon.name: "edit"
        enabled: root.isMyMessage &&
                 !root.editRestricted &&
                 !root.disabledForChat
    }

    StatusAction {
        id: copyMessageMenuItem
        text: qsTr("Copy message")
        icon.name: "copy"
        onTriggered: root.copyToClipboard(root.unparsedText)
        enabled: (root.messageContentType === Constants.messageContentType.messageType ||
                (root.messageContentType === Constants.messageContentType.imageType && root.unparsedText != "")) &&
                replyToMenuItem.enabled
    }

    StatusAction {
        id: copyMessageIdAction
        text: qsTr("Copy Message Id")
        icon.name: "copy"
        enabled: root.isDebugEnabled && replyToMenuItem.enabled
        onTriggered: root.copyToClipboard(root.messageId)
    }

    StatusAction {
        id: pinAction
        text: root.pinnedMessage ? qsTr("Unpin") : qsTr("Pin")
        icon.name: root.pinnedMessage ? "unpin" : "pin"
        onTriggered: {
            if (root.pinnedMessage) return root.unpinMessage()
            if (!root.canPin) return root.pinnedMessagesLimitReached()
            root.pinMessage()
        }
        enabled: {
            if (root.disabledForChat)
                return false

            switch (root.chatType) {
            case Constants.chatType.profile:
                return false
            case Constants.chatType.oneToOne:
                return true
            case Constants.chatType.privateGroupChat:
                return root.amIChatAdmin
            case Constants.chatType.communityChat:
                return root.amIChatAdmin || root.pinMessageAllowedForMembers
            default:
                return false
            }
        }
    }

    StatusAction {
        id: markMessageAsUnreadAction
        text: qsTr("Mark as unread")
        icon.name: "hide"
        enabled: !root.disabledForChat
        onTriggered: root.markMessageAsUnread()
    }

    StatusMenuSeparator {
        visible: deleteMessageAction.enabled &&
                 (replyToMenuItem.enabled ||
                  copyMessageMenuItem.enabled ||
                  copyMessageIdAction.enabled ||
                  editMessageAction.enabled ||
                  pinAction.enabled ||
                  markMessageAsUnreadAction.enabled)
        horizontalPadding: 0
    }

    StatusAction {
        id: deleteMessageAction
        enabled: (root.isMyMessage || root.amIChatAdmin) &&
                 !root.disabledForChat &&
                 (root.messageContentType === Constants.messageContentType.messageType ||
                  root.messageContentType === Constants.messageContentType.bridgeMessageType ||
                  root.messageContentType === Constants.messageContentType.stickerType ||
                  root.messageContentType === Constants.messageContentType.emojiType ||
                  root.messageContentType === Constants.messageContentType.imageType ||
                  root.messageContentType === Constants.messageContentType.audioType)
        text: qsTr("Delete message")
        icon.name: "delete"
        type: StatusAction.Type.Danger
        onTriggered: root.deleteMessage()
    }
}
