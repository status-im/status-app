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
    property bool threadsFeatureEnabled: false
    property bool hasThread: false
    property bool editRestricted: false
    property bool pinnedMessage: false
    property bool canPin: false
    property bool emojiReactionLimitReached: false
    property bool messageLinkSharingEnabled: false
    property bool openExpanded: false
    property bool expanded: openExpanded
    property bool deferCloseOnPressOutside: false
    property int closeOnPressOutsideRestoreDelay: 350
    readonly property bool isMyMessage: {
        return root.messageSenderId !== "" && root.messageSenderId === root.myPublicKey;
    }

    signal pinMessage()
    signal unpinMessage()
    signal pinnedMessagesLimitReached()
    signal showReplyArea(string messageSenderId)
    signal openThread()
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
        readonly property int menuPadding: root.Theme.defaultHalfPadding
        readonly property int compactPadding: menuPadding / 2
        readonly property int rowWidth: Math.max(0, root.maxImplicitWidth - 2 * menuPadding)
        readonly property int defaultItemSpacing: root.Theme.defaultPadding
        readonly property int defaultActionSize: iconSize + 2 * compactPadding
        readonly property int singleRowActionSize: iconSize + 3 * compactPadding
        readonly property bool editActionVisible: root.isMyMessage && !root.editRestricted && !root.disabledForChat
        readonly property bool compactPinActionVisible: !editActionVisible && d.canPinMessage
        readonly property bool reactionsVisible: !root.emojiReactionLimitReached && (!root.disabledForChat || root.forceEnableEmojiReactions)
        readonly property int singleRowActionCount: 1 +
                                                    (!root.disabledForChat ? 2 : 0) +
                                                    (editActionVisible ? 1 : 0) +
                                                    ((!!root.selectedText || d.canCopyMessage) ? 1 : 0) +
                                                    (compactPinActionVisible ? 1 : 0)
        readonly property int singleRowReactionsCountLimit: 3
        readonly property int singleRowReactionsWidth: (singleRowReactionsCountLimit + 1) * singleRowActionSize +
                                                       singleRowReactionsCountLimit * compactPadding
        readonly property int singleRowMenuWidth: 2 * compactPadding +
                                                 (reactionsVisible ? singleRowReactionsWidth + compactPadding : 0) +
                                                 singleRowActionCount * singleRowActionSize +
                                                 (singleRowActionCount - 1) * compactPadding
        readonly property int expandedMenuWidth: Math.max(defaultMenuWidth, singleRowMenuWidth)
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

    maxImplicitWidth: root.expanded ? (root.openExpanded ? d.defaultMenuWidth : d.expandedMenuWidth) : d.singleRowMenuWidth
    width: maxImplicitWidth
    verticalPadding: 0
    closePolicy: (d.closeOnPressOutside ? Popup.CloseOnPressOutside : Popup.NoAutoClose) | Popup.CloseOnEscape
    topPadding: d.menuPadding
    bottomPadding: d.menuPadding
    delegate: StatusMenuItem {
        visible: root.hideDisabledItems && !visibleOnDisabled ? enabled : true
        Layout.preferredHeight: visible ? implicitHeight : 0
        horizontalPadding: d.menuPadding
        verticalPadding: d.menuPadding
        spacing: d.defaultItemSpacing
        backgroundRadius: Math.max(d.menuPadding, Theme.radius)
        visualizeShortcuts: root.visualizeShortcuts
        rippleOrigin: root.rippleOrigin
        implicitWidth: root.maxImplicitWidth
        leftInset: d.menuPadding
        rightInset: d.menuPadding
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

    Item {
        objectName: "messageContextMenu_singleRowActions"
        visible: d.reactionsVisible || !root.expanded
        Layout.preferredWidth: root.maxImplicitWidth
        Layout.maximumWidth: root.maxImplicitWidth
        Layout.preferredHeight: root.expanded ? d.defaultActionSize : d.singleRowActionSize
        Layout.bottomMargin: root.expanded ? d.menuPadding : 0
        implicitWidth: Layout.preferredWidth

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.expanded ? d.menuPadding : d.compactPadding
            anchors.rightMargin: root.expanded ? d.menuPadding : d.compactPadding
            spacing: root.expanded ? d.defaultItemSpacing : d.compactPadding

            MessageReactionsRow {
                id: emojiRow
                objectName: "messageContextMenu_reactionsRow"

                size: MessageReactionsRow.Size.Compact
                addReactionIconColor: Theme.palette.primaryColor1
                countLimit: root.expanded ? 0 : d.singleRowReactionsCountLimit
                reactionSize: root.expanded ? d.defaultActionSize : d.singleRowActionSize
                spacing: root.expanded ? d.defaultItemSpacing : d.compactPadding

                Layout.preferredWidth: root.expanded ? d.rowWidth : d.singleRowReactionsWidth
                Layout.maximumWidth: root.expanded ? d.rowWidth : d.singleRowReactionsWidth
                Layout.preferredHeight: root.expanded ? d.defaultActionSize : d.singleRowActionSize
                Layout.fillWidth: true
                implicitWidth: Layout.preferredWidth

                visible: d.reactionsVisible
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
                visible: !root.expanded && !root.disabledForChat
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
                visible: !root.expanded && d.editActionVisible
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
                visible: !root.expanded && !root.disabledForChat
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
                visible: !root.expanded && (!!root.selectedText || d.canCopyMessage)
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
                objectName: "messageContextMenu_pin"
                visible: !root.expanded && d.compactPinActionVisible
                Layout.preferredWidth: d.singleRowActionSize
                Layout.preferredHeight: d.singleRowActionSize
                type: StatusFlatRoundButton.Type.Quaternary
                icon.name: root.pinnedMessage ? "unpin" : "pin"
                icon.width: d.iconSize
                icon.height: d.iconSize
                icon.color: Theme.palette.primaryColor1
                onClicked: {
                    if (root.pinnedMessage) root.unpinMessage()
                    else if (!root.canPin) root.pinnedMessagesLimitReached()
                    else root.pinMessage()
                    root.close()
                }
                onHoveredChanged: root.hoverChanged(hovered)
            }

            StatusFlatRoundButton {
                objectName: "messageContextMenu_expand"
                visible: !root.expanded
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
    }

    StatusMenuSeparator {
        objectName: "messageContextMenu_reactionsSeparator"
        visible: root.expanded && d.reactionsVisible
        horizontalPadding: d.menuPadding
        topPadding: 0
        bottomPadding: 0
        implicitWidth: root.maxImplicitWidth
    }

    Item {
        visible: root.expanded
        Layout.preferredHeight: d.menuPadding
    }

    MsgCtxAction {
        id: replyToMenuItem
        objectName: "messageContextMenu_replyTo"
        text: qsTr("Reply")
        icon.name: "reply"
        onTriggered: root.showReplyArea(root.messageSenderId)
        enabled: root.expanded && !root.disabledForChat
    }

    MsgCtxAction {
        id: openThreadAction
        objectName: "messageContextMenu_openThread"
        text: root.hasThread ? qsTr("Open Thread") : qsTr("Create Thread")
        icon.name: "chat"
        onTriggered: root.openThread()
        enabled: !root.disabledForChat &&
                root.threadsFeatureEnabled &&
                Utils.isThreadSupportedChatType(root.chatType)
    }

    MsgCtxAction {
        id: editMessageAction
        objectName: "messageContextMenu_edit"
        text: qsTr("Edit")
        onTriggered: root.editClicked()
        icon.name: "edit_pencil"
        enabled: root.expanded && d.editActionVisible
    }

    MsgCtxAction {
        id: markMessageAsUnreadAction
        objectName: "messageContextMenu_markUnread"
        text: qsTr("Mark as unread")
        icon.name: "hide"
        enabled: root.expanded && !root.disabledForChat
        onTriggered: root.markMessageAsUnread()
    }

    MsgCtxAction {
        id: copySelectedTextItem
        objectName: "messageContextMenu_copySelection"
        text: qsTr("Copy selected")
        icon.name: "copy_selected"
        enabled: root.expanded && !!root.selectedText
        onTriggered: root.copyToClipboard(root.selectedText)
    }

    MsgCtxAction {
        id: copyMessageMenuItem
        objectName: "messageContextMenu_copy"
        text: qsTr("Copy message")
        icon.name: "copy"
        onTriggered: root.copyToClipboard(root.unparsedText)
        enabled: root.expanded && d.canCopyMessage
    }

    MsgCtxAction {
        id: copyMessageLinkAction
        objectName: "messageContextMenu_copyLink"
        text: qsTr("Copy link to message")
        icon.name: "copy"
        enabled: root.expanded && root.messageLinkSharingEnabled
        onTriggered: root.copyMessageLink()
    }

    MsgCtxAction {
        id: pinAction
        objectName: "messageContextMenu_pin"
        text: root.pinnedMessage ? qsTr("Unpin") : qsTr("Pin")
        icon.name: root.pinnedMessage ? "unpin" : "pin"
        onTriggered: {
            if (root.pinnedMessage) return root.unpinMessage()
            if (!root.canPin) return root.pinnedMessagesLimitReached()
            root.pinMessage()
        }
        enabled: root.expanded && d.canPinMessage
    }

    MsgCtxAction {
        id: deleteMessageAction
        objectName: "messageContextMenu_delete"
        enabled: root.expanded && d.canDeleteMessage
        text: qsTr("Delete")
        icon.name: "delete"
        type: StatusAction.Danger
        onTriggered: root.deleteMessage()
    }

    component MsgCtxAction: StatusAction {
        icon.width: d.iconSize
        icon.height: d.iconSize
        fontSettings.pixelSize: root.Theme.primaryTextFontSize
    }
}
