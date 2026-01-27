import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import utils
import shared
import shared.stores as SharedStores
import shared.views
import shared.panels
import shared.popups
import shared.status
import shared.controls
import shared.views.chat

import AppLayouts.Chat.stores
import AppLayouts.stores as AppLayoutStores

import "../controls"
import "../panels"

Item {
    id: root

    property var chatContentModule

    property RootStore rootStore
    property MessageStore messageStore
    property string channelEmoji
    property var formatBalance

    // Users related data:
    property var usersModel

    // Contacts related data:
    property string myPublicKey

    property var emojiPopup
    property var stickersPopup
    property bool areTestNetworksEnabled

    property string chatId: ""
    property bool stickersLoaded: false
    property alias chatLogView: chatLogView
    property bool isContactBlocked: false
    property bool isChatBlocked: false
    property bool isOneToOne: false
    property bool joined

    property bool sendViaPersonalChatEnabled
    property string disabledTooltipText

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    signal openStickerPackPopup(string stickerPackId)
    signal tokenPaymentRequested(string recipientAddress, string tokenKey, string rawAmount)
    signal showReplyArea(string messageId, string author)
    signal editModeChanged(bool editModeOn)

    // Unfurling related requests:
    signal setNeverAskAboutUnfurlingAgain(bool neverAskAgain)

    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)

    // Contacts related requests:
    signal changeContactNicknameRequest(string pubKey, string nickname, string displayName, bool isEdit)
    signal removeTrustStatusRequest(string pubKey)
    signal dismissContactRequest(string chatId, string contactRequestId)
    signal acceptContactRequest(string chatId, string contactRequestId)

    // Community access related requests:
    signal spectateCommunityRequested(string communityId)

    QtObject {
        id: d

        readonly property real scrollY: chatLogView.visibleArea.yPosition * chatLogView.contentHeight
        readonly property bool isMostRecentMessageInViewport: chatLogView.visibleArea.yPosition >= 0.999 - chatLogView.visibleArea.heightRatio
        readonly property var chatDetails: chatContentModule && chatContentModule.chatDetails || null
        readonly property bool keepUnread: messageStore.keepUnread

        readonly property var loadMoreMessagesIfScrollBelowThreshold: Backpressure.oneInTimeQueued(root, 100, function() {
            if(scrollY < 1000) messageStore.loadMoreMessages()
        })

        function setKeepUnread(flag: bool) {
            root.messageStore.setKeepUnread(flag)
        }

        function markAllMessagesReadIfMostRecentMessageIsInViewport() {
            if (Qt.application.state != Qt.ApplicationActive || !isMostRecentMessageInViewport || !chatLogView.visible || keepUnread) {
                return
            }

            if (chatDetails && chatDetails.active && (chatDetails.hasUnreadMessages || chatDetails.highlight) && !messageStore.loading) {
                chatContentModule.markAllMessagesRead()
            }
        }

        function goToMessage(messageIndex) {
            chatLogView.currentIndex = -1
            chatLogView.currentIndex = messageIndex
        }

        onIsMostRecentMessageInViewportChanged: markAllMessagesReadIfMostRecentMessageIsInViewport()
    }

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive) {
                d.markAllMessagesReadIfMostRecentMessageIsInViewport()
            }
        }
    }

    Connections {
        target: root.messageStore.messageModule

        function onMessageSuccessfullySent() {
            chatLogView.positionViewAtBeginning()
        }

        function onSendingMessageFailed(error) {
            sendingMsgFailedPopup.error = error
            sendingMsgFailedPopup.open()
        }

        function onScrollToMessage(messageIndex) {
            d.goToMessage(messageIndex)
        }
    }

    Connections {
        target: root.messageStore

        function onMessageSearchOngoingChanged() {
            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        function onLoadingChanged() {
            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }
    }

    Connections {
        target: !!d.chatDetails ? d.chatDetails : null

        function onActiveChanged() {
            d.setKeepUnread(false)
            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
            d.loadMoreMessagesIfScrollBelowThreshold()
        }

        function onHasUnreadMessagesChanged() {
            if (!d.chatDetails.hasUnreadMessages) {
                return
            }

            // HACK: we call `addNewMessagesMarker` later because messages model
            // may not be yet propagated with unread messages when this signal is emitted
            if (chatLogView.visible && (Qt.application.state != Qt.ApplicationActive || !d.isMostRecentMessageInViewport)) {
                Qt.callLater(() => messageStore.addNewMessagesMarker())
            }
        }
    }

    Connections {
        target: root.rootStore
        enabled: d.chatDetails && d.chatDetails.active

        function onLoadingHistoryMessagesInProgressChanged() {
            if(!root.rootStore.loadingHistoryMessagesInProgress) {
                d.loadMoreMessagesIfScrollBelowThreshold()
            }
        }
    }

    Item {
        id: loadingMessagesIndicator
        visible: root.rootStore.loadingHistoryMessagesInProgress
        anchors.top: parent.top
        anchors.left: parent.left
        height: visible? 20 : 0
        width: parent.width

        Loader {
            active: root.rootStore.loadingHistoryMessagesInProgress
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: Component {
                LoadingAnimation {
                    width: 18
                    height: 18
                }
            }
        }
    }

    Loader {
        id: loadingMessagesView

        anchors.top: loadingMessagesIndicator.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        active: messageStore.loading
        visible: active
        sourceComponent: MessagesLoadingView {
            anchors.margins: 16
            anchors.fill: parent
        }
    }

    StatusListView {
        id: chatLogView
        visible: !loadingMessagesView.visible
        objectName: "chatLogView"
        anchors.top: loadingMessagesIndicator.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        leftMargin: Constants.primaryNavSidebarHandleWidth
        spacing: 0
        verticalLayoutDirection: ListView.BottomToTop
        cacheBuffer: height > 0 ? height * 2 : 0 // cache 2 screens worth of items

        highlightRangeMode: ListView.ApplyRange
        highlightMoveDuration: 200
        preferredHighlightBegin: 0
        preferredHighlightEnd: chatLogView.height / 2

        Binding on flickDeceleration {
            when: localAppSettings.isCustomMouseScrollingEnabled
            value: localAppSettings.scrollDeceleration
            restoreMode: Binding.RestoreBindingOrValue
        }

        Binding on maximumFlickVelocity {
            when: localAppSettings.isCustomMouseScrollingEnabled
            value: localAppSettings.scrollVelocity
            restoreMode: Binding.RestoreBindingOrValue
        }

        model: messageStore.messagesModel

        onContentYChanged: d.loadMoreMessagesIfScrollBelowThreshold()

        onCountChanged: {
            d.markAllMessagesReadIfMostRecentMessageIsInViewport()

            // after inilial messages are loaded
            // load as much messages as the view requires
            if (!messageStore.loading) {
                d.loadMoreMessagesIfScrollBelowThreshold()
            }
        }

        onVisibleChanged: d.markAllMessagesReadIfMostRecentMessageIsInViewport()

        onCurrentItemChanged: {
            if(currentItem && currentIndex > 0) {
                currentItem.startMessageFoundAnimation()
            }
        }

        ScrollBar.vertical: StatusScrollBar {
            visible: chatLogView.visibleArea.heightRatio < 1
        }

        ChatAnchorButtonsPanel {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: Theme.padding

            mentionsCount: d.chatDetails ? d.chatDetails.notificationCount : 0
            recentMessagesButtonVisible: {
                chatLogView.contentY // trigger binding on contentY change
                return chatLogView.contentHeight - (d.scrollY + chatLogView.height) > 400
            }

            onRecentMessagesButtonClicked: chatLogView.positionViewAtBeginning()
            onMentionsButtonClicked: {
                let id = messageStore.firstUnseenMentionMessageId()
                if (id !== "") {
                    messageStore.jumpToMessage(id)
                    chatContentModule.markMessageRead(id)
                }
            }
        }

        delegate: MessageView {
            id: msgDelegate

            width: ListView.view.width

            objectName: "chatMessageViewDelegate"

            rootStore: root.rootStore
            messageStore: root.messageStore
            channelEmoji: root.channelEmoji
            emojiPopup: root.emojiPopup
            stickersPopup: root.stickersPopup
            chatLogView: ListView.view
            chatContentModule: root.chatContentModule
            formatBalance: root.formatBalance
            usersModel: root.usersModel

            isChatBlocked: root.isChatBlocked
            joined: root.joined

            sendViaPersonalChatEnabled: root.sendViaPersonalChatEnabled
            disabledTooltipText: root.disabledTooltipText
            areTestNetworksEnabled: root.areTestNetworksEnabled

            chatId: root.chatId
            messageId: model.id
            communityId: model.communityId
            responseToMessageWithId: model.responseToMessageWithId
            senderId: model.senderId
            senderDisplayName: model.senderDisplayName
            usesDefaultName: model.usesDefaultName
            senderOptionalName: model.senderOptionalName
            senderIsEnsVerified: model.senderEnsVerified
            senderIcon: model.senderIcon
            senderIsAdded: model.senderIsAdded
            senderTrustStatus: model.senderTrustStatus
            compressedKey: model.compressedKey
            amISender: model.amISender
            messageText: model.messageText
            unparsedText: model.unparsedText
            messageImage: model.messageImage
            album: model.albumMessageImages.split(" ")
            albumCount: model.albumImagesCount
            messageTimestamp: model.timestamp
            messageOutgoingStatus: model.outgoingStatus
            resendError: model.resendError
            messageContentType: model.contentType
            pinnedMessage: model.pinned
            messagePinnedBy: model.pinnedBy
            reactionsModel: model.reactions
            sticker: model.sticker
            stickerPack: model.stickerPack
            editModeOn: model.editMode
            onEditModeOnChanged: root.editModeChanged(editModeOn)
            isEdited: model.isEdited
            deleted: model.deleted
            deletedBy: model.deletedBy
            deletedByContactDisplayName: model.deletedByContactDisplayName
            deletedByContactIcon: model.deletedByContactIcon
            linkPreviewModel: model.linkPreviewModel
            links: model.links
            paymentRequestModel: model.paymentRequestModel
            messageAttachments: model.messageAttachments
            transactionParams: model.transactionParameters
            hasMention: model.mentioned
            quotedMessageText: model.quotedMessageParsedText
            quotedMessageFrom: model.quotedMessageFrom
            quotedMessageContentType: model.quotedMessageContentType
            quotedMessageDeleted: model.quotedMessageDeleted
            quotedMessageAuthorDetailsName: model.quotedMessageAuthorName
            quotedMessageAuthorDetailsDisplayName: model.quotedMessageAuthorDisplayName
            quotedMessageAuthorDetailsThumbnailImage: model.quotedMessageAuthorThumbnailImage
            quotedMessageAuthorDetailsEnsVerified: model.quotedMessageAuthorEnsVerified
            quotedMessageAuthorDetailsIsContact: model.quotedMessageAuthorIsContact
            quotedMessageAlbumMessageImages: model.quotedMessageAlbumMessageImages.split(" ")
            quotedMessageAlbumImagesCount: model.quotedMessageAlbumImagesCount
            bridgeName: model.bridgeName

            gapFrom: model.gapFrom
            gapTo: model.gapTo

             // This is possible since we have all data loaded before we load qml.
             // When we fetch messages to fulfill a gap we have to set them at once.
             // Also one important thing here is that messages are set in descending order
             // in terms of `timestamp` of a message, that means a message with the most
             // recent time is added at index 0.
            prevMessageIndex: model.prevMsgIndex
            prevMessageTimestamp: model.prevMsgTimestamp
            prevMessageSenderId: model.prevMsgSenderId
            prevMessageContentType: model.prevMsgContentType
            prevMessageDeleted: model.prevMsgDeleted
            nextMessageIndex: model.nextMsgIndex
            nextMessageTimestamp: model.nextMsgTimestamp

            // Unfurling related data:
            gifUnfurlingEnabled: root.gifUnfurlingEnabled
            neverAskAboutUnfurlingAgain: root.neverAskAboutUnfurlingAgain

            // Contacts related data:
            myPublicKey: root.myPublicKey

            onOpenStickerPackPopup: {
                root.openStickerPackPopup(stickerPackId);
            }

            onTokenPaymentRequested: root.tokenPaymentRequested(recipientAddress, tokenKey, rawAmount)

            onShowReplyArea: {
                root.showReplyArea(messageId, author)
            }

            stickersLoaded: root.stickersLoaded

            onSendViaPersonalChatRequested: {
                Global.sendToRecipientRequested(recipientAddress)
            }

            onVisibleChanged: {
                if(!visible && model.editMode)
                    messageStore.setEditModeOff(model.id)
            }

            onEmojiReactionToggled: (messageId, hexcode) => {
                root.messageStore.toggleReaction(messageId, hexcode)
            }

            // Unfurling related requests:
            onSetNeverAskAboutUnfurlingAgain: root.setNeverAskAboutUnfurlingAgain(neverAskAgain)

            onOpenGifPopupRequest: root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)

            // Contacts related requests:
            onChangeContactNicknameRequest: root.changeContactNicknameRequest(pubKey, nickname, displayName, isEdit)
            onRemoveTrustStatusRequest: root.removeTrustStatusRequest(pubKey)

            // Community access related requests:
            onSpectateCommunityRequested: (communityId) => {
                root.spectateCommunityRequested(communityId)
            }
        }
        header: {
            if (!root.isContactBlocked && root.isOneToOne && root.rootStore.oneToOneChatContact) {
                switch (root.rootStore.oneToOneChatContact.contactRequestState) {
                case Constants.ContactRequestState.None: // no break
                case Constants.ContactRequestState.Dismissed:
                    return sendContactRequestComponent
                case Constants.ContactRequestState.Received:
                    return acceptOrDeclineContactRequestComponent
                case Constants.ContactRequestState.Sent:
                    return pendingContactRequestComponent
                default:
                    break
                }
            }
            return null
        }
        onHeaderChanged: chatLogView.positionViewAtBeginning()
    }

    StatusMessageDialog {
        property string error

        id: sendingMsgFailedPopup
        text: qsTr("Failed to send message.\n" + error)
        icon: StatusMessageDialog.StandardIcon.Critical
    }

    Component {
        id: sendContactRequestComponent

        StatusButton {
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            text: qsTr("Send Contact Request")
            onClicked: {
                Global.openContactRequestPopup(root.chatId, null)
            }
        }
    }

    Component {
        id: acceptOrDeclineContactRequestComponent

        RowLayout {
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

            StatusButton {
                text: qsTr("Reject Contact Request")
                type: StatusBaseButton.Type.Danger
                onClicked: {
                    root.dismissContactRequest(root.chatId, "")
                }
            }

            StatusButton {
                text: qsTr("Accept Contact Request")
                onClicked: {
                    root.acceptContactRequest(root.chatId, "")
                }
            }
        }
    }

    Component {
        id: pendingContactRequestComponent

        StatusButton {
            anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
            enabled: false
            text: qsTr("Contact Request Pending...")
        }
    }
}
