import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups
import StatusQ.Popups.Dialog

import utils
import shared.status
import shared.views.chat
import shared.stores as SharedStores

import AppLayouts.Chat.stores as ChatStores

StatusDialog {
    id: root

    property SharedStores.RootStore sharedRootStore
    property SharedStores.UtilsStore utilsStore
    property ChatStores.RootStore rootStore
    property var chatCommunitySectionModule
    property var memberMessagesModel: chatCommunitySectionModule.memberMessagesModel
    property string memberPubKey: ""
    property string displayName: ""
    property bool joined

    // Resolves mention pub keys to display names for the client-side renderer, mirroring
    // ChatMessagesView. Fed by the community's full member list; without it, "@0x…" mentions
    // render as raw keys.
    readonly property MentionResolver mentionResolver: MentionResolver {
        sourceModel: root.chatCommunitySectionModule?.membersModel ?? null
        nameRole: "preferredDisplayName"
    }


    width: 800

    title: qsTr("%1 messages").arg(root.displayName)
    subtitle: qsTr("%n message(s)", "", root.memberMessagesModel.count)

   ColumnLayout {
       anchors.fill: parent
        id: column

        StatusBaseText {
            visible: communityMemberMessageListView.count === 0
            text: qsTr("No messages")
            Layout.alignment: Qt.AlignCenter
            verticalAlignment: Text.AlignVCenter
            color: Theme.palette.secondaryText
            Layout.topMargin: 40
            Layout.bottomMargin: 40
        }

        StatusListView {
            id: communityMemberMessageListView
            model: root.memberMessagesModel
            Layout.fillWidth: true
            Layout.fillHeight: count
            implicitHeight: contentHeight

            delegate: Item {
                id: messageDelegate

                width: ListView.view.width
                height: messageItem.height

                MessageView {
                    id: messageItem

                    width: parent.width

                    rootStore: root.rootStore
                    chatCommunitySectionModule: root.chatCommunitySectionModule
                    messageStore: root.rootStore.messageStore
                    messageId: model.id
                    joined: root.joined
                    chatId: model.chatId
                    responseToMessageWithId: model.responseToMessageWithId
                    amIChatAdmin: true
                    senderId: model.senderId
                    senderDisplayName: model.senderDisplayName
                    senderOptionalName: model.senderOptionalName
                    senderIsEnsVerified: model.senderEnsVerified
                    senderIsAdded: model.senderIsAdded
                    senderIcon: model.senderIcon
                    senderTrustStatus: model.senderTrustStatus
                    amISender: model.amISender
                    messageText: model.messageText
                    unparsedText: model.unparsedText
                    mentionsMap: root.mentionResolver.map
                    messageImage: model.messageImage
                    messageTimestamp: model.timestamp
                    messageOutgoingStatus: model.outgoingStatus
                    messageContentType: model.contentType
                    pinnedMessage: model.pinned
                    messagePinnedBy: model.pinnedBy
                    sticker: model.sticker
                    stickerPack: model.stickerPack
                    linkPreviewModel: model.linkPreviewModel
                    links: model.links
                    transactionParams: model.transactionParameters
                    quotedMessageText: model.quotedMessageParsedText
                    quotedMessageFrom: model.quotedMessageFrom
                    quotedMessageContentType: model.quotedMessageContentType
                    quotedMessageDeleted: model.quotedMessageDeleted
                    quotedMessageAuthorDetailsName: model.quotedMessageAuthorName
                    quotedMessageAuthorDetailsDisplayName: model.quotedMessageAuthorDisplayName
                    quotedMessageAuthorDetailsThumbnailImage: model.quotedMessageAuthorThumbnailImage
                    quotedMessageAuthorDetailsEnsVerified: model.quotedMessageAuthorEnsVerified
                    quotedMessageAuthorDetailsIsContact: model.quotedMessageAuthorIsContact
                    bridgeName: model.bridgeName
                    isViewMemberMessagesePopup: true
                    shouldRepeatHeader: true

                    // Unfurling related data:
                    gifUnfurlingEnabled: root.sharedRootStore.gifUnfurlingEnabled
                    neverAskAboutUnfurlingAgain: root.sharedRootStore.neverAskAboutUnfurlingAgain

                    // Unfurling related requests:
                    onSetNeverAskAboutUnfurlingAgain: root.sharedRootStore.setNeverAskAboutUnfurlingAgain(neverAskAgain)
                }

                StatusMouseArea {
                    id: mouseArea
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    anchors.fill: parent

                    onClicked: {
                        root.chatCommunitySectionModule.openCommunityChatAndScrollToMessage(model.chatId, model.id)
                        Global.switchToCommunityChannelsView(root.chatCommunitySectionModule.getMySectionId())
                        root.chatCommunitySectionModule.openCommunityChatAndScrollToMessage(model.chatId, model.id)
                        root.closed()
                    }
                }
            }
        }
    }

    footer: StatusDialogFooter {
        id: footer
        rightButtons: ObjectModel {
            StatusFlatButton {
                text: qsTr("Delete all messages by %1").arg(root.displayName)
                enabled: communityMemberMessageListView.count > 0
                type: StatusBaseButton.Type.Danger
                onClicked: {
                    root.chatCommunitySectionModule.deleteCommunityMemberMessages(root.memberPubKey, "", "")
                }
                borderColor: "transparent"
            }

            StatusButton {
                text: qsTr("Done")
                onClicked: root.close()
            }
        }
    }
}
