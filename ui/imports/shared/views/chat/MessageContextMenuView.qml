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
    property bool openExpanded: false
    property bool expanded: false
    property bool collapsedSingleRow: false
    property bool deferCloseOnPressOutside: false
    property int closeOnPressOutsideRestoreDelay: 350
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

    QtObject {
        id: d
        property bool closeOnPressOutside: true

        readonly property int iconSize: 20
        readonly property int defaultMenuWidth: 234
        readonly property int menuPadding: Theme.halfPadding
        readonly property int compactPadding: menuPadding / 2
        readonly property int rowWidth: Math.max(0, root.maxImplicitWidth - 2 * menuPadding)
        readonly property int defaultItemSpacing: Theme.padding
        readonly property int defaultActionSize: iconSize + 2 * compactPadding
        readonly property int defaultReactionsCountLimit: 4
        readonly property int singleRowWidth: Math.max(0, root.maxImplicitWidth - 2 * compactPadding)
        readonly property int singleRowActionSize: iconSize + 3 * compactPadding
        readonly property int singleRowActionCount: 5
        readonly property int singleRowReactionsCountLimit: 3
        readonly property int singleRowReactionsWidth: (singleRowReactionsCountLimit + 1) * singleRowActionSize +
                                                       singleRowReactionsCountLimit * compactPadding
        readonly property int singleRowMenuWidth: 2 * compactPadding +
                                                 singleRowReactionsWidth +
                                                 singleRowActionCount * singleRowActionSize +
                                                 singleRowActionCount * compactPadding
        readonly property int compactReactionsBottomMargin: 6
        readonly property int expandIconRotation: 90
        readonly property bool canCopyMessage: (root.messageContentType === Constants.messageContentType.messageType ||
                                                root.messageContentType === Constants.messageContentType.contactRequestType ||
                                                root.messageContentType === Constants.messageContentType.bridgeMessageType ||
                                                (root.messageContentType === Constants.messageContentType.imageType && root.unparsedText != ""))
        readonly property bool canPinMessage: {
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
        readonly property bool canDeleteMessage: (root.isMyMessage || root.amIChatAdmin) &&
                                                 !root.disabledForChat &&
                                                 (root.messageContentType === Constants.messageContentType.messageType ||
                                                  root.messageContentType === Constants.messageContentType.bridgeMessageType ||
                                                  root.messageContentType === Constants.messageContentType.stickerType ||
                                                  root.messageContentType === Constants.messageContentType.emojiType ||
                                                  root.messageContentType === Constants.messageContentType.imageType ||
                                                  root.messageContentType === Constants.messageContentType.audioType)
    }

    maxImplicitWidth: root.collapsedSingleRow && !root.expanded ? d.singleRowMenuWidth : d.defaultMenuWidth
    verticalPadding: 0
    closePolicy: (d.closeOnPressOutside ? Popup.CloseOnPressOutside : Popup.NoAutoClose) | Popup.CloseOnEscape
    topPadding: d.menuPadding
    bottomPadding: d.menuPadding
    delegate: StatusMenuItem {
        visible: root.hideDisabledItems && !visibleOnDisabled ? enabled : true
        Layout.preferredHeight: visible ? implicitHeight : 0
        Layout.leftMargin: d.menuPadding
        Layout.rightMargin: d.menuPadding
        horizontalPadding: d.menuPadding
        verticalPadding: d.menuPadding
        spacing: d.defaultItemSpacing
        backgroundRadius: Math.max(d.menuPadding, Theme.radius)
        visualizeShortcuts: root.visualizeShortcuts
        rippleOrigin: root.rippleOrigin
    }

    onOpened: {
        root.expanded = root.openExpanded
        if (root.deferCloseOnPressOutside) {
            d.closeOnPressOutside = false
            restoreCloseOnPressOutsideTimer.restart()
        }
    }

    Timer {
        id: restoreCloseOnPressOutsideTimer
        interval: root.closeOnPressOutsideRestoreDelay
        onTriggered: d.closeOnPressOutside = true
    }

    HoverHandler {
        id: hoverHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onHoveredChanged: root.hoverChanged(hovered)
    }

    MessageReactionsRow {
        id: emojiRow
        objectName: "messageContextMenu_reactionsRow"

        size: MessageReactionsRow.Size.Compact
        addReactionIconColor: Theme.palette.primaryColor1
        countLimit: root.collapsedSingleRow && root.expanded ? 0 : d.defaultReactionsCountLimit
        reactionSize: d.defaultActionSize
        spacing: d.defaultItemSpacing
        implicitWidth: d.rowWidth

        Layout.topMargin: 0
        Layout.bottomMargin: root.expanded ? d.menuPadding : d.compactReactionsBottomMargin
        Layout.leftMargin: d.menuPadding
        Layout.rightMargin: d.menuPadding
        Layout.preferredWidth: d.rowWidth
        Layout.maximumWidth: d.rowWidth

        visible: (!root.emojiReactionLimitReached && (!root.disabledForChat || root.forceEnableEmojiReactions)) && (!root.collapsedSingleRow || root.expanded)
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
        Layout.leftMargin: d.compactPadding
        Layout.rightMargin: d.compactPadding
        Layout.preferredWidth: d.singleRowWidth
        Layout.maximumWidth: d.singleRowWidth
        Layout.bottomMargin: 0
        spacing: d.compactPadding

        MessageReactionsRow {
            objectName: "messageContextMenu_landscapeReactionsRow"

            size: MessageReactionsRow.Size.Compact
            addReactionIconColor: Theme.palette.primaryColor1
            countLimit: d.singleRowReactionsCountLimit
            spacing: d.compactPadding

            Layout.preferredWidth: d.singleRowReactionsWidth
            Layout.maximumWidth: d.singleRowReactionsWidth

            visible: (!root.emojiReactionLimitReached && (!root.disabledForChat || root.forceEnableEmojiReactions))
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

        StatusFlatRoundButton {
            objectName: "messageContextMenu_replyTo"
            visible: !root.disabledForChat
            Layout.preferredWidth: d.singleRowActionSize
            Layout.preferredHeight: d.singleRowActionSize
            type: StatusFlatRoundButton.Type.Quaternary
            icon.name: "reply"
            icon.width: d.iconSize
            icon.height: d.iconSize
            icon.color: Theme.palette.primaryColor1
            onClicked: {
                root.showReplyArea(root.messageSenderId)
                root.close()
            }
            onHoveredChanged: root.hoverChanged(hovered)
        }

        StatusFlatRoundButton {
            objectName: "messageContextMenu_edit"
            enabled: (root.isMyMessage && !root.editRestricted && !root.disabledForChat)
            Layout.preferredWidth: d.singleRowActionSize
            Layout.preferredHeight: d.singleRowActionSize
            type: StatusFlatRoundButton.Type.Quaternary
            icon.name: "edit_pencil"
            icon.width: d.iconSize
            icon.height: d.iconSize
            icon.color: Theme.palette.primaryColor1
            onClicked: {
                root.editClicked()
                root.close()
            }
            onHoveredChanged: root.hoverChanged(hovered)
        }

        StatusFlatRoundButton {
            objectName: "messageContextMenu_markUnread"
            visible: !root.disabledForChat
            Layout.preferredWidth: d.singleRowActionSize
            Layout.preferredHeight: d.singleRowActionSize
            type: StatusFlatRoundButton.Type.Quaternary
            icon.name: "hide"
            icon.width: d.iconSize
            icon.height: d.iconSize
            icon.color: Theme.palette.primaryColor1
            onClicked: {
                root.markMessageAsUnread()
                root.close()
            }
            onHoveredChanged: root.hoverChanged(hovered)
        }

        StatusFlatRoundButton {
            objectName: "messageContextMenu_copy"
            visible: !!root.selectedText || d.canCopyMessage
            Layout.preferredWidth: d.singleRowActionSize
            Layout.preferredHeight: d.singleRowActionSize
            type: StatusFlatRoundButton.Type.Quaternary
            icon.name: "copy"
            icon.width: d.iconSize
            icon.height: d.iconSize
            icon.color: Theme.palette.primaryColor1
            onClicked: {
                root.copyToClipboard(!!root.selectedText ? root.selectedText : root.unparsedText)
                root.close()
            }
            onHoveredChanged: root.hoverChanged(hovered)
        }

        StatusFlatRoundButton {
            objectName: "messageContextMenu_expand"
            Layout.preferredWidth: d.singleRowActionSize
            Layout.preferredHeight: d.singleRowActionSize
            type: StatusFlatRoundButton.Type.Quaternary
            icon.name: "more"
            icon.width: d.iconSize
            icon.height: d.iconSize
            icon.color: Theme.palette.primaryColor1
            icon.rotation: d.expandIconRotation
            onClicked: root.expanded = true
            onHoveredChanged: root.hoverChanged(hovered)
        }
    }

    RowLayout {
        visible: !root.expanded && !root.collapsedSingleRow
        Layout.leftMargin: d.menuPadding
        Layout.rightMargin: d.menuPadding
        Layout.preferredWidth: d.rowWidth
        Layout.maximumWidth: d.rowWidth
        Layout.bottomMargin: 0
        spacing: d.defaultItemSpacing

        StatusFlatRoundButton {
            objectName: "messageContextMenu_replyTo"
            visible: !root.disabledForChat
            Layout.preferredWidth: d.defaultActionSize
            Layout.preferredHeight: d.defaultActionSize
            type: StatusFlatRoundButton.Type.Quaternary
            icon.name: "reply"
            icon.width: d.iconSize
            icon.height: d.iconSize
            icon.color: Theme.palette.primaryColor1
            onClicked: {
                root.showReplyArea(root.messageSenderId)
                root.close()
            }
            onHoveredChanged: root.hoverChanged(hovered)
        }

        StatusFlatRoundButton {
            objectName: "messageContextMenu_edit"
            enabled: (root.isMyMessage && !root.editRestricted && !root.disabledForChat)
            Layout.preferredWidth: d.defaultActionSize
            Layout.preferredHeight: d.defaultActionSize
            type: StatusFlatRoundButton.Type.Quaternary
            icon.name: "edit_pencil"
            icon.width: d.iconSize
            icon.height: d.iconSize
            icon.color: Theme.palette.primaryColor1
            onClicked: {
                root.editClicked()
                root.close()
            }
            onHoveredChanged: root.hoverChanged(hovered)
        }

        StatusFlatRoundButton {
            objectName: "messageContextMenu_markUnread"
            visible: !root.disabledForChat
            Layout.preferredWidth: d.defaultActionSize
            Layout.preferredHeight: d.defaultActionSize
            type: StatusFlatRoundButton.Type.Quaternary
            icon.name: "hide"
            icon.width: d.iconSize
            icon.height: d.iconSize
            icon.color: Theme.palette.primaryColor1
            onClicked: {
                root.markMessageAsUnread()
                root.close()
            }
            onHoveredChanged: root.hoverChanged(hovered)
        }

        StatusFlatRoundButton {
            objectName: "messageContextMenu_copy"
            visible: !!root.selectedText || d.canCopyMessage
            Layout.preferredWidth: d.defaultActionSize
            Layout.preferredHeight: d.defaultActionSize
            type: StatusFlatRoundButton.Type.Quaternary
            icon.name: "copy"
            icon.width: d.iconSize
            icon.height: d.iconSize
            icon.color: Theme.palette.primaryColor1
            onClicked: {
                root.copyToClipboard(!!root.selectedText ? root.selectedText : root.unparsedText)
                root.close()
            }
            onHoveredChanged: root.hoverChanged(hovered)
        }

        StatusFlatRoundButton {
            objectName: "messageContextMenu_expand"
            Layout.preferredWidth: d.defaultActionSize
            Layout.preferredHeight: d.defaultActionSize
            type: StatusFlatRoundButton.Type.Quaternary
            icon.name: "more"
            icon.width: d.iconSize
            icon.height: d.iconSize
            icon.color: Theme.palette.primaryColor1
            icon.rotation: d.expandIconRotation
            onClicked: root.expanded = true
            onHoveredChanged: root.hoverChanged(hovered)
        }
    }

    Item {
        visible: root.expanded
        Layout.preferredHeight: d.menuPadding
    }

    StatusAction {
        id: replyToMenuItem
        objectName: "messageContextMenu_replyTo"
        text: qsTr("Reply")
        icon.name: "reply"
        icon.width: d.iconSize
        icon.height: d.iconSize
        fontSettings.pixelSize: Theme.primaryTextFontSize
        onTriggered: root.showReplyArea(root.messageSenderId)
        enabled: root.expanded && !root.disabledForChat
    }

    StatusAction {
        id: editMessageAction
        objectName: "messageContextMenu_edit"
        text: qsTr("Edit")
        onTriggered: root.editClicked()
        icon.name: "edit_pencil"
        icon.width: d.iconSize
        icon.height: d.iconSize
        fontSettings.pixelSize: Theme.primaryTextFontSize
        enabled: root.expanded && (root.isMyMessage && !root.editRestricted && !root.disabledForChat)
    }

    StatusAction {
        id: markMessageAsUnreadAction
        objectName: "messageContextMenu_markUnread"
        text: qsTr("Mark as unread")
        icon.name: "hide"
        icon.width: d.iconSize
        icon.height: d.iconSize
        fontSettings.pixelSize: Theme.primaryTextFontSize
        enabled: root.expanded && !root.disabledForChat
        onTriggered: root.markMessageAsUnread()
    }

    StatusAction {
        id: copySelectedTextItem
        objectName: "messageContextMenu_copySelection"
        text: qsTr("Copy")
        icon.name: "copy"
        icon.width: d.iconSize
        icon.height: d.iconSize
        fontSettings.pixelSize: Theme.primaryTextFontSize
        enabled: root.expanded && !!root.selectedText
        onTriggered: root.copyToClipboard(root.selectedText)
    }

    StatusAction {
        id: copyMessageMenuItem
        objectName: "messageContextMenu_copy"
        text: qsTr("Copy message")
        icon.name: "copy"
        icon.width: d.iconSize
        icon.height: d.iconSize
        fontSettings.pixelSize: Theme.primaryTextFontSize
        onTriggered: root.copyToClipboard(root.unparsedText)
        enabled: root.expanded && d.canCopyMessage
    }

    StatusAction {
        id: copyMessageLinkAction
        objectName: "messageContextMenu_copyLink"
        text: qsTr("Copy link to message")
        icon.name: "copy"
        icon.width: d.iconSize
        icon.height: d.iconSize
        fontSettings.pixelSize: Theme.primaryTextFontSize
        enabled: root.expanded && root.messageLinkSharingEnabled
        onTriggered: root.copyMessageLink()
    }

    StatusAction {
        id: pinAction
        objectName: "messageContextMenu_pin"
        text: root.pinnedMessage ? qsTr("Unpin") : qsTr("Pin")
        icon.name: root.pinnedMessage ? "unpin" : "pin"
        icon.width: d.iconSize
        icon.height: d.iconSize
        fontSettings.pixelSize: Theme.primaryTextFontSize
        onTriggered: {
            if (root.pinnedMessage) return root.unpinMessage()
            if (!root.canPin) return root.pinnedMessagesLimitReached()
            root.pinMessage()
        }
        enabled: root.expanded && d.canPinMessage
    }

    StatusAction {
        id: deleteMessageAction
        objectName: "messageContextMenu_delete"
        enabled: root.expanded && d.canDeleteMessage
        text: qsTr("Delete")
        icon.name: "delete"
        icon.width: d.iconSize
        icon.height: d.iconSize
        fontSettings.pixelSize: Theme.primaryTextFontSize
        assetSettings.color: Theme.palette.dangerColor1
        onTriggered: root.deleteMessage()
    }
}
