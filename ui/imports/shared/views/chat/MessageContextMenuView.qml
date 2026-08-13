import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Popups
import StatusQ.Components
import StatusQ.Controls

import utils
import shared.controls.chat

StatusMenu {
    id: root
    objectName: "MessageContextMenuView"

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
    property string selectedText

    property bool pinMessageAllowedForMembers: false
    property bool editRestricted: false
    property bool pinnedMessage: false
    property bool canPin: false
    property bool emojiReactionLimitReached: false
    property bool messageLinkSharingEnabled: false
    property bool initiallyExpanded: false
    property bool expanded: false
    property bool collapsedSingleRow: false
    property bool deferCloseOnPressOutside: false
    property bool closeOnPressOutside: true
    readonly property alias hovered: hoverHandler.hovered
    readonly property bool reactionsVisible: !root.emojiReactionLimitReached &&
                                             (!root.disabledForChat || root.forceEnableEmojiReactions)
    readonly property int reactionsRowHorizontalMargin: 8
    readonly property int reactionsRowMaximumWidth: Math.max(0, root.maxImplicitWidth - reactionsRowHorizontalMargin * 2)
    readonly property bool replyEnabled: !root.disabledForChat
    readonly property bool editEnabled: root.isMyMessage &&
                                        !root.editRestricted &&
                                        !root.disabledForChat
    readonly property bool markMessageAsUnreadEnabled: !root.disabledForChat
    readonly property bool copySelectedTextEnabled: !!root.selectedText
    readonly property bool copyMessageEnabled: (root.messageContentType === Constants.messageContentType.messageType ||
                                                root.messageContentType === Constants.messageContentType.contactRequestType ||
                                                root.messageContentType === Constants.messageContentType.bridgeMessageType ||
                                                (root.messageContentType === Constants.messageContentType.imageType && root.unparsedText != ""))
    readonly property bool copyMessageLinkActionEnabled: root.messageLinkSharingEnabled
    readonly property bool pinEnabled: {
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
    readonly property bool deleteEnabled: (root.isMyMessage || root.amIChatAdmin) &&
                                          !root.disabledForChat &&
                                          (root.messageContentType === Constants.messageContentType.messageType ||
                                           root.messageContentType === Constants.messageContentType.bridgeMessageType ||
                                           root.messageContentType === Constants.messageContentType.stickerType ||
                                           root.messageContentType === Constants.messageContentType.emojiType ||
                                           root.messageContentType === Constants.messageContentType.imageType ||
                                           root.messageContentType === Constants.messageContentType.audioType)
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
    signal copyMessageLink()
    signal openEmojiPopup(var parent, var mouse)
    signal hoverChanged(bool hovered)

    maxImplicitWidth: root.collapsedSingleRow && !root.expanded ? 352 : 234
    menuItemsFillWidth: true
    verticalPadding: 0
    closePolicy: (root.closeOnPressOutside ? Popup.CloseOnPressOutside : Popup.NoAutoClose) | Popup.CloseOnEscape
    topPadding: Math.max(8, Theme.halfPadding)
    bottomPadding: Math.max(8, Theme.halfPadding)
    background: Rectangle {
    color: "transparent"
    }
    delegate: StatusMenuItem {
        visible: root.hideDisabledItems && !visibleOnDisabled ? enabled : true
        Layout.preferredHeight: visible ? implicitHeight : 0
        Layout.leftMargin: Math.max(8, Theme.halfPadding)
        Layout.rightMargin: Math.max(8, Theme.halfPadding)
        horizontalPadding: Math.max(8, Theme.halfPadding)
        spacing: Math.max(8, Theme.halfPadding)
        iconSize: 20
        fontPixelSize: Theme.primaryTextFontSize
        backgroundRadius: Math.max(8, Theme.radius)
        visualizeShortcuts: root.visualizeShortcuts
        rippleOrigin: root.rippleOrigin
    }

    onOpened: {
        root.expanded = root.initiallyExpanded
        if (root.deferCloseOnPressOutside) {
            root.closeOnPressOutside = false
            restoreCloseOnPressOutsideTimer.restart()
        }
    }

    Timer {
        id: restoreCloseOnPressOutsideTimer
        interval: 350
        onTriggered: root.closeOnPressOutside = true
    }

    HoverHandler {
        id: hoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onHoveredChanged: root.hoverChanged(hovered)
    }

    component CollapsedActionButton: StatusFlatRoundButton {
        Layout.preferredWidth: 42
        Layout.preferredHeight: 42
        type: StatusFlatRoundButton.Type.Quaternary
        icon.width: 24
        icon.height: 24
        icon.color: Theme.palette.primaryColor1
        onHoveredChanged: root.hoverChanged(hovered)
    }

    MessageReactionsRow {
        id: emojiRow
        objectName: "messageContextMenu_reactionsRow"

        size: MessageReactionsRow.Size.Big
        emojiSize: 32
        itemSize: 42
        addReactionIconColor: Theme.palette.primaryColor1
        countLimit: 4
        spacing: 0
        implicitWidth: root.reactionsRowMaximumWidth

        Layout.topMargin: 0
        Layout.bottomMargin: root.expanded ? Math.max(8, Theme.halfPadding) : 6
        Layout.leftMargin: root.reactionsRowHorizontalMargin
        Layout.rightMargin: root.reactionsRowHorizontalMargin
        Layout.preferredWidth: root.reactionsRowMaximumWidth
        Layout.maximumWidth: root.reactionsRowMaximumWidth

        visible: root.reactionsVisible && (!root.collapsedSingleRow || root.expanded)
        emojiModel: root.emojiModel
        onToggleReaction: hexcode => {
            root.toggleReaction(hexcode)
            root.close()
        }
        onOpenEmojiPopup: (parent, mouse) => {
            root.openEmojiPopup(parent, mouse)
            root.close()
        }

        HoverHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: root.hoverChanged(hovered)
        }
    }

    StatusMenuSeparator {
        visible: root.expanded && emojiRow.visible && !root.disabledForChat
        topPadding: 0
        bottomPadding: 0
        horizontalPadding: 0
    }

    RowLayout {
        visible: !root.expanded && root.collapsedSingleRow
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.preferredWidth: root.maxImplicitWidth - 16
        Layout.maximumWidth: root.maxImplicitWidth - 16
        Layout.bottomMargin: 0
        spacing: 0

        MessageReactionsRow {
            objectName: "messageContextMenu_landscapeReactionsRow"

            size: MessageReactionsRow.Size.Big
            emojiSize: 32
            itemSize: 42
            addReactionIconColor: Theme.palette.primaryColor1
            countLimit: 4
            spacing: 0

            Layout.preferredWidth: 210
            Layout.maximumWidth: 210

            visible: root.reactionsVisible
            emojiModel: root.emojiModel
            onToggleReaction: hexcode => {
                root.toggleReaction(hexcode)
                root.close()
            }
            onOpenEmojiPopup: (parent, mouse) => {
                root.openEmojiPopup(parent, mouse)
                root.close()
            }

            HoverHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onHoveredChanged: root.hoverChanged(hovered)
            }
        }

        CollapsedActionButton {
            objectName: "messageContextMenu_replyTo"
            visible: root.replyEnabled
            icon.name: "reply"
            onClicked: {
                root.showReplyArea(root.messageSenderId)
                root.close()
            }
        }

        CollapsedActionButton {
            objectName: "messageContextMenu_edit"
            enabled: root.editEnabled
            icon.name: "edit_pencil"
            onClicked: {
                root.editClicked()
                root.close()
            }
        }

        CollapsedActionButton {
            objectName: "messageContextMenu_expand"
            icon.name: "more"
            icon.rotation: 90
            onClicked: root.expanded = true
        }
    }

    RowLayout {
        visible: !root.expanded && !root.collapsedSingleRow
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.preferredWidth: root.maxImplicitWidth - 16
        Layout.maximumWidth: root.maxImplicitWidth - 16
        Layout.bottomMargin: 0
        spacing: 0

        CollapsedActionButton {
            objectName: "messageContextMenu_replyTo"
            visible: root.replyEnabled
            icon.name: "reply"
            onClicked: {
                root.showReplyArea(root.messageSenderId)
                root.close()
            }
        }

        CollapsedActionButton {
            objectName: "messageContextMenu_edit"
            enabled: root.editEnabled
            icon.name: "edit_pencil"
            onClicked: {
                root.editClicked()
                root.close()
            }
        }

        CollapsedActionButton {
            objectName: "messageContextMenu_markUnread"
            visible: root.markMessageAsUnreadEnabled
            icon.name: "hide"
            onClicked: {
                root.markMessageAsUnread()
                root.close()
            }
        }

        CollapsedActionButton {
            objectName: "messageContextMenu_copy"
            visible: root.copySelectedTextEnabled || root.copyMessageEnabled
            icon.name: "copy"
            onClicked: {
                root.copyToClipboard(root.copySelectedTextEnabled ? root.selectedText : root.unparsedText)
                root.close()
            }
        }

        CollapsedActionButton {
            objectName: "messageContextMenu_expand"
            icon.name: "more"
            icon.rotation: 90
            onClicked: root.expanded = true
        }
    }

    Item {
        visible: root.expanded
        Layout.preferredHeight: Math.max(8, Theme.padding)
    }

    StatusAction {
        id: replyToMenuItem
        objectName: "messageContextMenu_replyTo"
        text: qsTr("Reply")
        icon.name: "reply"
        onTriggered: root.showReplyArea(root.messageSenderId)
        enabled: root.expanded && root.replyEnabled
    }

    StatusAction {
        id: editMessageAction
        objectName: "messageContextMenu_edit"
        text: qsTr("Edit")
        onTriggered: root.editClicked()
        icon.name: "edit_pencil"
        enabled: root.expanded && root.editEnabled
    }

    StatusAction {
        id: markMessageAsUnreadAction
        objectName: "messageContextMenu_markUnread"
        text: qsTr("Mark as unread")
        icon.name: "hide"
        enabled: root.expanded && root.markMessageAsUnreadEnabled
        onTriggered: root.markMessageAsUnread()
    }

    StatusAction {
        id: copySelectedTextItem
        objectName: "messageContextMenu_copySelection"
        text: qsTr("Copy")
        icon.name: "copy"
        enabled: root.expanded && root.copySelectedTextEnabled
        onTriggered: root.copyToClipboard(root.selectedText)
    }

    StatusAction {
        id: copyMessageMenuItem
        objectName: "messageContextMenu_copy"
        text: qsTr("Copy message")
        icon.name: "copy"
        onTriggered: root.copyToClipboard(root.unparsedText)
        enabled: root.expanded && root.copyMessageEnabled
    }

    StatusAction {
        id: copyMessageLinkAction
        objectName: "messageContextMenu_copyLink"
        text: qsTr("Copy link to message")
        icon.name: "copy"
        enabled: root.expanded && root.copyMessageLinkActionEnabled
        onTriggered: root.copyMessageLink()
    }

    StatusAction {
        id: pinAction
        objectName: "messageContextMenu_pin"
        text: root.pinnedMessage ? qsTr("Unpin") : qsTr("Pin")
        icon.name: root.pinnedMessage ? "unpin" : "pin"
        onTriggered: {
            if (root.pinnedMessage) return root.unpinMessage()
            if (!root.canPin) return root.pinnedMessagesLimitReached()
            root.pinMessage()
        }
        enabled: root.expanded && root.pinEnabled
    }

    StatusAction {
        id: deleteMessageAction
        objectName: "messageContextMenu_delete"
        enabled: root.expanded && root.deleteEnabled
        text: qsTr("Delete")
        icon.name: "delete"
        assetSettings.color: Theme.palette.dangerColor1
        onTriggered: root.deleteMessage()
    }

    Item {
        visible: root.expanded
        Layout.preferredHeight: Math.max(8, Theme.padding)
    }
}
