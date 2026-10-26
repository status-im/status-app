import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups

import utils
import shared.status
import shared.views.chat
import AppLayouts.Chat.adaptors
import AppLayouts.Chat.stores

StatusListView {
    id: root

    property RootStore store
    property MessageStore messageStore
    property string messageToPin
    readonly property string messageToUnpin: pinButtonGroup.checkedButton?.messageId ?? ""
    property string chatId
    property bool joined

    property bool isPinActionAvailable: true

    // Resolves mention pub keys to display names for the client-side renderer, mirroring
    // ChatMessagesView: the group chat's users (none in a community channel) plus every
    // named contact, then the message's own mentionedNames, then an alias (whose
    // profile is then requested).
    readonly property MentionNamesAdaptor mentionNames: MentionNamesAdaptor {
        chatUsersModel: root.store?.usersStore.usersModel ?? null
        contactsModel: root.store?.contactsModel ?? null
    }

    readonly property MentionResolver mentionResolver: MentionResolver {
        sourceModel: root.mentionNames?.model ?? null
        nameRole: "preferredDisplayName"
        selfPubKey: root.store?.myPublicKey() ?? ""
        selfName: root.store?.name ?? ""
        aliasProvider: pubKey => root.store?.generateAlias(pubKey) ?? ""
        contactInfoRequester: pubKey => root.store?.requestContactInfo(pubKey)
    }

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    signal unpinMessageRequested(string messageId)
    signal jumpToMessageRequested(string messageId)
    signal setNeverAskAboutUnfurlingAgain(bool neverAskAgain)
    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)

    ButtonGroup {
        id: pinButtonGroup
    }

    delegate: Item {
        id: messageDelegate

        width: ListView.view.width
        height: messageItem.height

        MessageView {
            id: messageItem

            width: parent.width

            rootStore: root.store
            messageStore: root.messageStore
            chatContentModule: root.store?.currentChatContentModule() ?? null
            chatCommunitySectionModule: root.store?.chatCommunitySectionModule ?? null
            chatId: root.chatId

            joined: root.joined
            messageId: model.id
            responseToMessageWithId: model.responseToMessageWithId
            senderId: model.senderId
            senderDisplayName: model.senderDisplayName
            senderOptionalName: model.senderOptionalName
            senderIsEnsVerified: model.senderEnsVerified
            senderIsAdded: model.senderIsAdded
            senderIcon: model.senderIcon
            senderTrustStatus: model.senderTrustStatus
            amISender: model.amISender
            unparsedText: model.unparsedText
            mentionsMap: root.mentionResolver.resolveFor(model.unparsedText + " " + model.quotedMessageText,
                                                         model.mentionedNames)
            messageImage: model.messageImage
            messageTimestamp: model.timestamp
            messageOutgoingStatus: model.outgoingStatus
            messageContentType: model.contentType
            pinnedMessage: model.pinned
            messagePinnedBy: model.pinnedBy
            reactionsModel: model.reactions
            sticker: model.sticker
            stickerPack: model.stickerPack
            linkPreviewModel: model.linkPreviewModel
            links: model.links
            transactionParams: model.transactionParameters
            quotedMessageUnparsedText: model.quotedMessageText
            quotedMessageFrom: model.quotedMessageFrom
            quotedMessageContentType: model.quotedMessageContentType
            quotedMessageDeleted: model.quotedMessageDeleted
            quotedMessageAuthorDetailsName: model.quotedMessageAuthorName
            quotedMessageAuthorDetailsDisplayName: model.quotedMessageAuthorDisplayName
            quotedMessageAuthorDetailsThumbnailImage: model.quotedMessageAuthorThumbnailImage
            quotedMessageAuthorDetailsEnsVerified: model.quotedMessageAuthorEnsVerified
            quotedMessageAuthorDetailsIsContact: model.quotedMessageAuthorIsContact
            bridgeName: model.bridgeName

            prevMessageIndex: -1
            nextMessageIndex: -1
            prevMessageAsJsonObj: null
            nextMessageAsJsonObj: null

            // Additional params
            isInPinnedPopup: true
            shouldRepeatHeader: true

            // Unfurling related data:
            gifUnfurlingEnabled: root.gifUnfurlingEnabled
            neverAskAboutUnfurlingAgain: root.neverAskAboutUnfurlingAgain

            // Unfurling related requests:
            onSetNeverAskAboutUnfurlingAgain: root.setNeverAskAboutUnfurlingAgain(neverAskAgain)

            onOpenGifPopupRequest: root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)
        }

        StatusMouseArea {
            id: mouseArea
            objectName: "pinnedMessagesPopup_delegateMouseArea"
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 55
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                           switch (mouse.button) {
                               case Qt.RightButton:
                                   Global.openMenu(pinnedPopupMessageContextMenuComponent, this, {
                                                       messageId: messageItem.messageId,
                                                   }, Qt.point(mouse.x, mouse.y))
                                   break
                               case Qt.LeftButton:
                                   if (!!root.messageToPin) {
                                       if (!radio.checked)
                                        radio.checked = true
                                   } else {
                                       root.jumpToMessageRequested(model.id)
                                   }
                                   break
                           }
            }
        }

        StatusFlatRoundButton {
            id: unpinButton
            objectName: "pinnedMessagesPopup_unpinButton"
            anchors.top: parent.top
            anchors.topMargin: Theme.bigPadding
            anchors.right: parent.right
            anchors.rightMargin: Theme.bigPadding
            z: mouseArea.z + 1
            width: 32
            height: 32
            visible: root.isPinActionAvailable && !root.messageToPin && (hovered || mouseArea.containsMouse)
            icon.name: "unpin"
            tooltip.text: qsTr("Unpin")
            color: hovered ? Theme.palette.primaryColor2 : Theme.palette.indirectColor4
            onClicked: {
                root.unpinMessageRequested(model.id)
            }
        }

        StatusRadioButton {
            id: radio
            objectName: "pinnedMessagesPopup_radio"
            readonly property string messageId: model.id
            visible: root.messageToPin
            anchors.right: parent.right
            anchors.rightMargin: Theme.bigPadding
            anchors.verticalCenter: parent.verticalCenter
            ButtonGroup.group: pinButtonGroup
        }

        Component {
            id: pinnedPopupMessageContextMenuComponent

            StatusMenu {
                id: messageContextMenu

                objectName: "pinnedMessagesPopup_messageContextMenu"
                property string messageId

                StatusAction {
                    objectName: "pinnedMessagesPopup_unpin"
                    text: qsTr("Unpin")
                    icon.name: "unpin"
                    enabled: root.isPinActionAvailable
                    onTriggered: {
                        root.messageStore.unpinMessage(messageContextMenu.messageId)
                        close()
                    }
                }

                StatusAction {
                    objectName: "pinnedMessagesPopup_jumpTo"
                    text: qsTr("Jump to")
                    icon.name: "arrow-up"
                    onTriggered: {
                        root.jumpToMessageRequested(messageContextMenu.messageId)
                        close()
                    }
                }

                onOpened: {
                    messageItem.setMessageActive(model.id, true)
                }
                onClosed: {
                    messageItem.setMessageActive(model.id, false)
                    destroy()
                }
            }
        }
    }
}
