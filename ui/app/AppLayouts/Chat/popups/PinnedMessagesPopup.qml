import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups
import StatusQ.Popups.Dialog

import utils
import shared.status
import shared.views.chat
import shared.stores as SharedStores

import AppLayouts.Chat.controls
import AppLayouts.Chat.adaptors
import AppLayouts.Chat.stores

StatusDialog {
    id: root

    objectName: "PinnedMessagesPopup"

    property SharedStores.UtilsStore utilsStore
    property RootStore store
    property MessageStore messageStore
    property var pinnedMessagesModel //this doesn't belong to the messageStore, it is a part of the ChatContentStore, but we didn't introduce it yet.
    property string messageToPin
    property string messageToUnpin
    property string chatId
    property bool joined

    property bool isPinActionAvailable: true

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    signal pinMessageRequested(string messageId)
    signal unpinMessageRequested(string messageId)
    signal jumpToMessageRequested(string messageId)
    signal setNeverAskAboutUnfurlingAgain(bool neverAskAgain)
    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)

    width: 800
    implicitHeight: 428
    padding: 0
    fillHeightOnBottomSheet: true

    title: root.messageToPin ? qsTr("Pin limit reached") : qsTr("Pinned messages")
    subtitle: root.messageToPin ? qsTr("Unpin a previous message first")
                                : qsTr("%n message(s)", "", pinnedMessageListView.count)

    QtObject {
        id: d

        function jumpToMessage(messageId) {
            root.close()
            root.jumpToMessageRequested(messageId)
        }
    }

    contentItem: ColumnLayout {
        id: column

        StatusBaseText {
            objectName: "pinnedMessagesPopup_emptyState"
            visible: pinnedMessageListView.count === 0
            text: qsTr("Pinned messages will appear here.")
            Layout.alignment: Qt.AlignCenter
            verticalAlignment: Text.AlignVCenter
            color: Theme.palette.secondaryText
        }

        PinnedMessagesList {
            id: pinnedMessageListView
            objectName: "pinnedMessagesPopup_listView"
            model: root.pinnedMessagesModel
            store: root.store
            messageStore: root.messageStore
            chatId: root.chatId
            joined: root.joined
            messageToPin: root.messageToPin
            isPinActionAvailable: root.isPinActionAvailable
            gifUnfurlingEnabled: root.gifUnfurlingEnabled
            neverAskAboutUnfurlingAgain: root.neverAskAboutUnfurlingAgain
            Layout.fillWidth: true
            Layout.fillHeight: count
            implicitHeight: contentHeight
            onMessageToUnpinChanged: root.messageToUnpin = messageToUnpin
            onUnpinMessageRequested: messageId => root.unpinMessageRequested(messageId)
            onJumpToMessageRequested: messageId => d.jumpToMessage(messageId)
            onSetNeverAskAboutUnfurlingAgain: neverAskAgain => root.setNeverAskAboutUnfurlingAgain(neverAskAgain)
            onOpenGifPopupRequest: (params, cbOnGifSelected, cbOnClose) => root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)
        }

        // The list's bottom corners follow the dialog's: computed by the
        // shader on the column's layer, with no second layer for a mask
        layer.enabled: root.visible && !root.messageToPin
        layer.effect: StatusRoundedCornersEffect {
            bottomLeftRadius: background.radius
            bottomRightRadius: background.radius
        }
    }

    footer: StatusDialogFooter {
        id: footer
        bottomPadding: Theme.padding + root.parent.SafeArea.margins.bottom
        visible: !!root.messageToPin
        rightButtons: ObjectModel {
            StatusButton {
                objectName: "pinnedMessagesPopup_confirmPinButton"
                visible: footer.visible
                enabled: !!root.messageToUnpin
                text: qsTr("Unpin selected message and pin new message")
                onClicked: {
                    root.unpinMessageRequested(root.messageToUnpin)
                    root.messageToUnpin = ""
                    root.pinMessageRequested(root.messageToPin)
                    root.messageToPin = ""
                    root.close()
                }
            }
        }
    }
}
