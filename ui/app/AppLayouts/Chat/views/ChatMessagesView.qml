import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import SortFilterProxyModel 0.2

import StatusQ.Core.Utils as SQUtils

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

    // Resolves mention pub keys to display names. Reactive to member/contact
    // name changes; "everyone" is built in.
    MentionResolver {
        id: mentionResolver

        enabled: root.visible
        sourceModel: root.usersModel
        nameRole: "preferredDisplayName"
    }

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
    property bool messageLinkSharingEnabled
    property string disabledTooltipText

    property int extraLeftPadding: 0

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    signal openStickerPackPopup(string stickerPackId)
    signal tokenPaymentRequested(string recipientAddress, string tokenKey, string rawAmount)
    signal showReplyArea(string messageId, string author)
    signal editModeChanged(bool editModeOn, string messageId)

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
        objectName: "chatMessagesViewInternal"

        readonly property bool isMostRecentMessageInViewport: chatLogView.atNewest
        readonly property var chatDetails: chatContentModule && chatContentModule.chatDetails || null
        readonly property bool keepUnread: messageStore.keepUnread

        // Sliding model window over messageStore.messagesModel (source row 0 =
        // newest); the view only ever holds the window's rows, never the history.
        // The initial size is derived from the viewport (assuming compact rows)
        // so the placeholder cannot start on screen and fire paging on open.
        readonly property int assumedMinRowHeight: 24
        readonly property int estimatedViewportRows: Math.ceil(chatLogView.height / d.assumedMinRowHeight)
        readonly property int initialWindowSize: Math.max(20, Math.min(d.maxWindowSize,
                                                                       d.estimatedViewportRows))
        readonly property int windowChunkSize: 30
        readonly property int maxWindowSize: 140

        property int windowStart: 0
        property int windowEnd: initialWindowSize - 1

        // Goals the live bounds walk towards a few rows per frame (windowDriver):
        // admitting a whole window in one dispatch stalls slow devices for
        // seconds. Shrinking only destroys rows and is applied at once.
        readonly property int moveBudget: 8
        property int windowStartGoal: 0
        property int windowEndGoal: initialWindowSize - 1

        // The chat identifier (clock -2) is the last row of every chat; the
        // backend keeps a fetch-more row (clock -1) directly above it for as
        // long as older messages can be requested. History is exhausted only
        // when the identifier is not preceded by that row. The count heuristic
        // alone never settles (fetch churn re-arms it).
        property bool historyExhausted: false

        function updateHistoryExhausted() {
            const model = root.messageStore?.messagesModel ?? null
            if (!model || model.count === 0) {
                historyExhausted = false
                return
            }
            const last = SQUtils.ModelUtils.get(model, model.count - 1, "contentType")
            const beforeLast = model.count > 1
                    ? SQUtils.ModelUtils.get(model, model.count - 2, "contentType")
                    : undefined
            historyExhausted = last === Constants.messageContentType.chatIdentifier
                    && beforeLast !== Constants.messageContentType.fetchMoreMessagesButton
        }

        // The initial size is re-derived once the view has a height; growth
        // only, shrinking would destroy rows the viewport may be showing.
        property bool windowAtInitial: true

        onInitialWindowSizeChanged: {
            if (d.windowAtInitial && d.initialWindowSize - 1 > d.windowEndGoal)
                d.windowEndGoal = d.initialWindowSize - 1
        }

        readonly property int historyCount: messageStore.messagesModel ? messageStore.messagesModel.count : 0

        // History count at the last fetch: stops the placeholder once a fetch
        // brings nothing, re-arms when history grows.
        property int lastFetchHistoryCount: -1
        readonly property bool mayFetchMoreHistory: d.historyCount !== d.lastFetchHistoryCount

        readonly property bool olderMessagesAvailable: d.historyCount > 0
                                                       && (d.windowEnd < d.historyCount - 1
                                                           || (!d.historyExhausted
                                                               && (d.mayFetchMoreHistory
                                                                   || root.rootStore.loadingHistoryMessagesInProgress)))

        function resetWindow() {
            windowStart = 0
            windowEnd = Math.min(initialWindowSize, moveBudget) - 1
            windowStartGoal = 0
            windowEndGoal = initialWindowSize - 1
            windowAtInitial = true
            lastFetchHistoryCount = -1
        }

        function slideWindowToHistory() {
            if (d.windowEndGoal < d.historyCount - 1) {
                d.windowAtInitial = false
                d.windowEndGoal = Math.min(d.historyCount - 1, d.windowEndGoal + d.windowChunkSize)
                if (d.windowEndGoal - d.windowStartGoal + 1 > d.maxWindowSize)
                    d.windowStartGoal = d.windowEndGoal - d.maxWindowSize + 1
                return
            }

            if (root.rootStore.loadingHistoryMessagesInProgress || d.historyExhausted
                    || !d.mayFetchMoreHistory)
                return

            d.lastFetchHistoryCount = d.historyCount
            messageStore.loadMoreMessages()
        }

        function slideWindowToRecent() {
            if (d.windowStartGoal <= 0)
                return

            d.windowStartGoal = Math.max(0, d.windowStartGoal - d.windowChunkSize)
            if (d.windowEndGoal - d.windowStartGoal + 1 > d.maxWindowSize)
                d.windowEndGoal = d.windowStartGoal + d.maxWindowSize - 1
        }

        // QSFPM only re-evaluates inserted rows; nudge the bound so the filter
        // re-checks all rows (deferred — the proxy may lag the source change).
        function refilterWindow() {
            const end = d.windowEnd
            d.windowEnd = end + 1
            d.windowEnd = end
        }

        // Moves the window so that a source index sits in the middle of it and
        // can therefore be scrolled to.
        function centerWindowOn(messageIndex) {
            d.windowAtInitial = false
            // a tiny instant window around the target so it can be positioned
            // at once; growth happens on the history side only, keeping the
            // target's window row stable while rows stream in below it
            d.windowStart = Math.max(0, messageIndex - 2)
            d.windowEnd = messageIndex + 2
            d.windowStartGoal = d.windowStart
            d.windowEndGoal = Math.max(d.windowEnd,
                                       Math.min(d.historyCount - 1,
                                                d.windowStart + d.maxWindowSize - 1))
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
            d.centerWindowOn(messageIndex)
            chatLogView.positionAtRow(messageIndex - d.windowStart)
        }

        // Slides the window to the recent end without rebuilding it — a reset
        // here would destroy and regrow the delegates on every sent message.
        function scrollToBottom() {
            if (d.windowStart > 0 || d.windowStartGoal > 0) {
                d.windowStart = 0
                d.windowStartGoal = 0
                if (d.windowEndGoal - d.windowStartGoal + 1 > d.maxWindowSize)
                    d.windowEndGoal = d.maxWindowSize - 1
            }
            chatLogView.positionAtNewest()
            markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        onIsMostRecentMessageInViewportChanged: markAllMessagesReadIfMostRecentMessageIsInViewport()
    }

    // Source-model inserts and removals below the window would otherwise shift
    // which messages the index window selects; keep it pinned to the same rows.
    Connections {
        target: root.messageStore?.messagesModel ?? null

        function onRowsInserted(parent, first, last) {
            if (d.windowStart > 0 && first <= d.windowStart) {
                const inserted = last - first + 1
                d.windowStart += inserted
                d.windowEnd += inserted
                d.windowStartGoal += inserted
                d.windowEndGoal += inserted
            }
            if (first <= d.windowEnd)
                Qt.callLater(d.refilterWindow)
            Qt.callLater(d.updateHistoryExhausted)
        }

        function onRowsRemoved(parent, first, last) {
            if (d.windowStart > 0 && first < d.windowStart) {
                const removed = Math.min(last, d.windowStart - 1) - first + 1
                d.windowStart -= removed
                d.windowEnd -= removed
                d.windowStartGoal = Math.max(0, d.windowStartGoal - removed)
                d.windowEndGoal = Math.max(d.windowEnd, d.windowEndGoal - removed)
            }
            if (first <= d.windowEnd)
                Qt.callLater(d.refilterWindow)
            Qt.callLater(d.updateHistoryExhausted)
        }
    }

    // Walks the live window bounds towards their goals a few rows per frame,
    // so a window move admits its delegates in small batches across frames
    // instead of building them all inside a single dispatch.
    Timer {
        id: windowDriver

        interval: 16
        repeat: true
        triggeredOnStart: true
        running: d.windowEnd !== d.windowEndGoal || d.windowStart !== d.windowStartGoal

        onTriggered: {
            if (d.windowEnd > d.windowEndGoal)
                d.windowEnd = d.windowEndGoal
            else if (d.windowEnd < d.windowEndGoal)
                d.windowEnd = Math.min(d.windowEndGoal, d.windowEnd + d.moveBudget)

            if (d.windowStart < d.windowStartGoal)
                d.windowStart = d.windowStartGoal
            else if (d.windowStart > d.windowStartGoal)
                d.windowStart = Math.max(d.windowStartGoal, d.windowStart - d.moveBudget)
        }
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
            d.scrollToBottom()
        }

        function onSendingMessageFailed(error) {
            sendingMsgFailedPopup.error = error
            sendingMsgFailedPopup.open()
        }

        function onReactionActionFailed(addAction, error) {
            Global.displayToastMessage(
                        addAction ? qsTr("Couldn't add reaction") : qsTr("Couldn't remove reaction"),
                        qsTr("Please try again later"),
                        "warning",
                        false,
                        Constants.ephemeralNotificationType.danger,
                        "")
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
            if (!messageStore.loading && chatLogView.stickingToNewest) {
                Qt.callLater(d.scrollToBottom)
            }
        }
    }

    Connections {
        target: !!d.chatDetails ? d.chatDetails : null

        function onActiveChanged() {
            if (active && chatLogView.stickingToNewest) {
                Qt.callLater(d.scrollToBottom)
            }

            d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        function onHasUnreadMessagesChanged() {
            if (!d.chatDetails.hasUnreadMessages) {
                return
            }

            // The marker enters the view when the window slides over it.
            // HACK: we call `addNewMessagesMarker` later because messages model
            // may not be yet propagated with unread messages when this signal is emitted
            if (chatLogView.visible && (Qt.application.state != Qt.ApplicationActive || !d.isMostRecentMessageInViewport)) {
                Qt.callLater(() => messageStore.addNewMessagesMarker())
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

    ChatMessagesFlickable {
        id: chatLogView
        visible: !messageStore.loading
        objectName: "chatLogView"
        anchors.top: loadingMessagesIndicator.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        contentBottomPadding: Theme.halfPadding

        moreUpAvailable: d.olderMessagesAvailable
        moreDownAvailable: d.windowStart > 0

        onMoreUpRequested: d.slideWindowToHistory()
        onMoreDownRequested: d.slideWindowToRecent()

        onRowPositioned: row => {
            const item = chatLogView.itemAtRow(row)
            if (item && item.startMessageFoundAnimation)
                item.startMessageFoundAnimation()
        }

        onMovementEnded: d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        onVisibleChanged: d.markAllMessagesReadIfMostRecentMessageIsInViewport()

        placeholder: MessageRowsSkeleton {}

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

        // The view is handed only the [windowStart..windowEnd] slice. The
        // source stays detached until the initial fetch is done — attaching
        // earlier costs one incubation per row; the covering skeleton in
        // ChatContentView hides both that phase and the view's incubation.
        model: SortFilterProxyModel {
            id: messagesWindow

            sourceModel: messageStore.loading ? null : messageStore.messagesModel
            onSourceModelChanged: {
                d.resetWindow()
                d.updateHistoryExhausted()
                // whatever the paging timer did against the detached window,
                // the view opens on the newest message
                if (sourceModel)
                    Qt.callLater(chatLogView.positionAtNewest)
            }

            filters: IndexFilter {
                minimumIndex: d.windowStart
                maximumIndex: d.windowEnd
            }

            onCountChanged: d.markAllMessagesReadIfMostRecentMessageIsInViewport()
        }

        ScrollBar.vertical: StatusScrollBar {
            visible: chatLogView.contentHeight > chatLogView.height
        }

        delegate: MessageView {
            id: msgDelegate

            objectName: "chatMessageViewDelegate"

            // Row 0 is the newest message and belongs at the bottom
            Layout.row: root.chatLogView.rowCount - index
            Layout.column: 0
            // Hard-pin the cell width (as ListView did) instead of fillWidth:
            // message implicit-width echoes livelock the GridLayout otherwise.
            Layout.preferredWidth: root.chatLogView.width
            Layout.minimumWidth: root.chatLogView.width
            Layout.maximumWidth: root.chatLogView.width

            rootStore: root.rootStore
            messageStore: root.messageStore
            channelEmoji: root.channelEmoji
            emojiPopup: root.emojiPopup
            stickersPopup: root.stickersPopup
            chatLogView: root.chatLogView
            chatContentModule: root.chatContentModule
            formatBalance: root.formatBalance
            usersModel: root.usersModel
            // covers the message body and the quoted reply, whose mentions
            // also render through this map
            mentionsMap: mentionResolver.resolveFor(model.unparsedText + " " + model.quotedMessageText)

            isChatBlocked: root.isChatBlocked
            joined: root.joined

            sendViaPersonalChatEnabled: root.sendViaPersonalChatEnabled
            messageLinkSharingEnabled: root.messageLinkSharingEnabled
            createMessageLink: (chatId, messageId) => root.messageStore.createMessageLink(chatId, messageId)
            disabledTooltipText: root.disabledTooltipText
            areTestNetworksEnabled: root.areTestNetworksEnabled
            extraLeftPadding: root.extraLeftPadding

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
            onEditModeOnChanged: root.editModeChanged(editModeOn, model.id)
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
            quotedMessageUnparsedText: model.quotedMessageText
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

            onOpenStickerPackPopup: stickerPackId => root.openStickerPackPopup(stickerPackId)
            onTokenPaymentRequested: root.tokenPaymentRequested(recipientAddress, tokenKey, rawAmount)

            onShowReplyArea: (messageId, author) => root.showReplyArea(messageId, author)

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
        bottomContent: {
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
    }

    ChatAnchorButtonsPanel {
        anchors.bottom: chatLogView.bottom
        anchors.bottomMargin: Theme.padding
        anchors.right: chatLogView.right
        anchors.rightMargin: Theme.padding

        visible: chatLogView.visible

        // Don't show the mention anchor in 1-1 chats, because all messages count as mentions
        mentionsCount: d.chatDetails && d.chatDetails.type !== Constants.chatType.oneToOne ?
                    d.chatDetails.notificationCount : 0
        recentMessagesCount: root.messageStore.newMessagesCount
        recentMessagesButtonVisible: chatLogView.moreDownAvailable
                                     || chatLogView.contentHeight - chatLogView.contentY - chatLogView.height > 400

        onRecentMessagesButtonClicked: d.scrollToBottom()
        onMentionsButtonClicked: {
            let id = messageStore.firstUnseenMentionMessageId()
            if (id !== "") {
                messageStore.jumpToMessage(id)
                chatContentModule.markMessageRead(id)
            }
        }
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

        Item {
            id: contactRequestActions

            readonly property real horizontalMargin: Theme.bigPadding + Theme.halfPadding
            readonly property real verticalMargin: Theme.padding
            readonly property real naturalWidth: rejectContactRequestButton.implicitWidth +
                                                 acceptContactRequestButton.implicitWidth +
                                                 buttonsRow.spacing
            readonly property real availableWidth: Math.max(0, width - 2 * horizontalMargin)
            readonly property bool compact: availableWidth < naturalWidth
            readonly property real compactButtonWidth: Math.max(0, (availableWidth - buttonsRow.spacing) / 2)

            width: parent ? parent.width : naturalWidth + 2 * horizontalMargin
            implicitHeight: buttonsRow.implicitHeight + 2 * verticalMargin

            RowLayout {
                id: buttonsRow

                anchors.centerIn: parent
                width: Math.min(contactRequestActions.naturalWidth, contactRequestActions.availableWidth)
                spacing: Theme.padding

                StatusButton {
                    id: rejectContactRequestButton

                    Layout.fillWidth: contactRequestActions.compact
                    Layout.preferredWidth: contactRequestActions.compact ? contactRequestActions.compactButtonWidth : implicitWidth
                    Layout.maximumWidth: contactRequestActions.compact ? contactRequestActions.compactButtonWidth : implicitWidth
                    textFillWidth: contactRequestActions.compact
                    text: qsTr("Reject Contact Request")
                    type: StatusBaseButton.Type.Danger
                    onClicked: {
                        root.dismissContactRequest(root.chatId, "")
                    }
                }

                StatusButton {
                    id: acceptContactRequestButton

                    Layout.fillWidth: contactRequestActions.compact
                    Layout.preferredWidth: contactRequestActions.compact ? contactRequestActions.compactButtonWidth : implicitWidth
                    Layout.maximumWidth: contactRequestActions.compact ? contactRequestActions.compactButtonWidth : implicitWidth
                    textFillWidth: contactRequestActions.compact
                    text: qsTr("Accept Contact Request")
                    onClicked: {
                        root.acceptContactRequest(root.chatId, "")
                    }
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
