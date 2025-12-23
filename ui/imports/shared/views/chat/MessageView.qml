import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts
import QtModelsToolkit

import utils
import shared.panels
import shared.status
import shared.controls
import shared.popups
import shared.views.chat
import shared.controls.chat
import shared.stores as SharedStores
import shared.popups.send

import StatusQ
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Controls
import StatusQ.Components

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Profile.helpers

Loader {
    id: root

    property ChatStores.RootStore rootStore
    property ChatStores.MessageStore messageStore
    property var chatContentModule
    property var chatCommunitySectionModule

    property string channelEmoji

    property var chatLogView
    property var emojiPopup
    property var stickersPopup

    // Unfurling related data:
    property bool gifUnfurlingEnabled
    property bool neverAskAboutUnfurlingAgain

    // Once we redo qml we will know all section/chat related details in each message form the parent components
    // without an explicit need to fetch those details via message store/module.
    property bool isChatBlocked: false

    property bool joined: false

    property string chatId
    property string messageId: ""
    property string communityId: ""

    property string senderId: ""
    property string senderDisplayName: ""
    property bool usesDefaultName: false
    property string senderOptionalName: ""
    property bool senderIsEnsVerified: false
    property string senderIcon: ""
    property bool amISender: false
    property bool amIChatAdmin: messageStore && messageStore.amIChatAdmin
    property bool senderIsAdded: false
    property int senderTrustStatus: Constants.trustStatus.unknown
    property string compressedKey: ""
    property string messageText: ""
    property string unparsedText: ""
    property string messageImage: ""
    property double messageTimestamp: 0 // We use double, because QML's int is too small
    property string messageOutgoingStatus: ""
    property string resendError: ""
    property int messageContentType: Constants.messageContentType.messageType

    property bool pinnedMessage: false
    property string messagePinnedBy: ""
    property var reactionsModel
    readonly property bool emojiReactionLimitReached: {
        if (!root.reactionsModel) {
            return true
        }
        return root.reactionsModel.ModelCount.count >= Constants.maxEmojiReactionsPerMessage
    }

    property var linkPreviewModel
    property var paymentRequestModel
    property string messageAttachments: ""
    property var transactionParams
    property var formatBalance

    // These 2 properties can be dropped when the new unfurling flow supports GIFs
    property var links
    readonly property var gifLinks: {
        if (!links)
            return []
        const arr = links.split(" ")
        return arr.filter(value => value.toLowerCase().endsWith('.gif'))
    }

    property string responseToMessageWithId: ""
    property string quotedMessageText: ""
    property string quotedMessageFrom: ""
    property int quotedMessageContentType: Constants.messageContentType.messageType
    property int quotedMessageFromIterator: -1
    property bool quotedMessageDeleted: false
    property string quotedMessageAuthorDetailsName: ""
    property string quotedMessageAuthorDetailsDisplayName: ""
    property string quotedMessageAuthorDetailsThumbnailImage: ""
    property bool quotedMessageAuthorDetailsEnsVerified: false
    property bool quotedMessageAuthorDetailsIsContact: false

    property var album: []
    property int albumCount: 0

    property var quotedMessageAlbumMessageImages: []
    property int quotedMessageAlbumImagesCount: 0

    // External behavior changers
    property bool isInPinnedPopup: false // The pinned popup limits the number of buttons shown
    property bool isViewMemberMessagesePopup: false // The view member messages popup limits the number of buttons
    property bool disableHover: false // Used to force the HoverHandler to be active (useful for messages in popups)
    property bool placeholderMessage: false

    property int gapFrom: 0
    property int gapTo: 0

    property int prevMessageIndex: -1
    property int prevMessageContentType: prevMessageAsJsonObj ? prevMessageAsJsonObj.contentType : Constants.messageContentType.unknownContentType
    property bool prevMessageDeleted: false
    property double prevMessageTimestamp: prevMessageAsJsonObj ? prevMessageAsJsonObj.timestamp : 0
    property string prevMessageSenderId: prevMessageAsJsonObj ? prevMessageAsJsonObj.senderId : ""
    property var prevMessageAsJsonObj
    property int nextMessageIndex: -1
    property double nextMessageTimestamp: nextMessageAsJsonObj ? nextMessageAsJsonObj.timestamp : 0
    property var nextMessageAsJsonObj

    readonly property bool editRestricted: root.isSticker
    property bool editModeOn: false
    property bool isEdited: false

    property bool deleted: false
    property string deletedBy: ""
    property string deletedByContactDisplayName: ""
    property string deletedByContactIcon: ""

    property bool shouldRepeatHeader: d.shouldRepeatHeader

    property bool hasMention: false

    property bool sendViaPersonalChatEnabled
    property string disabledTooltipText

    property bool areTestNetworksEnabled

    property bool stickersLoaded: false
    property string sticker
    property int stickerPack: -1
    property string bridgeName: ""

    property bool isEmoji: messageContentType === Constants.messageContentType.emojiType
    property bool isImage: messageContentType === Constants.messageContentType.imageType || (isDiscordMessage && messageImage != "")
    property bool isSticker: messageContentType === Constants.messageContentType.stickerType
    property bool isDiscordMessage: messageContentType === Constants.messageContentType.discordMessageType
    property bool isBridgeMessage: messageContentType === Constants.messageContentType.bridgeMessageType
    property bool isText: messageContentType === Constants.messageContentType.messageType || messageContentType === Constants.messageContentType.contactRequestType || isDiscordMessage || isBridgeMessage
    property bool isMessage: isEmoji || isImage || isSticker || isText
                             || messageContentType === Constants.messageContentType.communityInviteType || messageContentType === Constants.messageContentType.transactionType

    // Users related data:
    property var usersModel

    // Contacts related data:
    property string myPublicKey

    // Contacts related requests:
    signal changeContactNicknameRequest(string pubKey, string nickname, string displayName, bool isEdit)
    signal removeTrustStatusRequest(string pubKey)

    // Community access related requests:
    signal spectateCommunityRequested(string communityId)

    signal emojiReactionToggled(string messageId, string hexcode)

    property var senderContactEntry: ContactModelEntry {
        publicKey: root.senderId
        contactsModel: root.rootStore.contactsModel
        onPopulateContactDetailsRequested: root.rootStore.populateContactDetailsRequested(root.senderId)
    }

    property var quotedMessageFromContactEntryLoader: Loader {
        active: !!root.quotedMessageFrom
        sourceComponent: ContactModelEntry {
            publicKey: root.quotedMessageFrom
            contactsModel: root.rootStore.contactsModel
            onPopulateContactDetailsRequested: root.rootStore.populateContactDetailsRequested(root.quotedMessageFrom)
        }
    }

    property var messagePinnedByContactEntryLoader: Loader {
        active: !!root.messagePinnedBy
        sourceComponent: ContactModelEntry {
            publicKey: root.messagePinnedBy
            contactsModel: root.rootStore.contactsModel
            onPopulateContactDetailsRequested: root.rootStore.populateContactDetailsRequested(root.messagePinnedBy)
        }
    }

    function openProfileContextMenu(x, y, isReply = false) {
        if (isViewMemberMessagesePopup)
            return false

        // The responseTo message was deleted
        // so we don't enable to right click the unavailable profile
        if (isReply && !quotedMessageFrom)
            return false

        const pubKey = isReply ? root.quotedMessageFrom : root.senderId
        const isBridgedAccount = isReply ? (quotedMessageContentType === Constants.messageContentType.bridgeMessageType)
                                         : root.isBridgeMessage

        const contactDetails = isReply ? root.quotedMessageFromContactEntryLoader.item.contactDetails
                                       : root.senderContactEntry.contactDetails
        const isMe = pubKey === root.myPublicKey

        const profileType = Utils.getProfileType(isMe, isBridgedAccount, contactDetails.isBlocked)
        const contactType = Utils.getContactType(contactDetails.contactRequestState, contactDetails.isContact)
        const chatType = chatContentModule.chatDetails.type
        // set false for now, because the remove from group option is still available after member is removed
        const isAdmin = false // chatContentModule.amIChatAdmin()

        const params = {
            pubKey, profileType, contactType, chatType, isAdmin,
            compressedPubKey: contactDetails.compressedPubKey,
            displayName: isReply ? quotedMessageAuthorDetailsDisplayName : root.senderDisplayName,
            userIcon: isReply ? quotedMessageAuthorDetailsThumbnailImage : root.senderIcon,
            colorId: Utils.colorIdForPubkey(pubKey),
            trustStatus: contactDetails.trustStatus,
            onlineStatus: contactDetails.onlineStatus,
            usesDefaultName: contactDetails.usesDefaultName,
            hasLocalNickname: !!contactDetails.localNickname
        }

        profileContextMenuComponent.createObject(root, params).popup(x, y)
    }

    function openMessageContextMenu(x, y) {
        if (isViewMemberMessagesePopup || placeholderMessage || !root.joined)
            return

        if (root.isChatBlocked && !d.addReactionAllowed)
            return

        const params = {
            myPublicKey: userProfile.pubKey,
            amIChatAdmin: root.amIChatAdmin,
            pinMessageAllowedForMembers: messageStore.isPinMessageAllowedForMembers,
            chatType: messageStore.chatType,

            messageId: root.messageId,
            unparsedText: root.unparsedText,
            messageSenderId: root.senderId,
            messageContentType: root.messageContentType,
            pinnedMessage: root.pinnedMessage,
            canPin: !!root.messageStore && root.messageStore.getNumberOfPinnedMessages() < Constants.maxNumberOfPins,
            editRestricted: root.editRestricted,
        }

        messageContextMenuComponent.createObject(root, params).popup(x, y)
    }

    function setMessageActive(messageId, active) {

        // TODO: Is argument messageId actually needed?
        //       It was probably used with dynamic scoping,
        //       but not this method can be moved to private `d`.
        //       Probably that it was done this way, because `MessageView` is reused as delegate.

        if (active) {
            d.activeMessage = messageId;
            return;
        }
        if (d.activeMessage === messageId) {
            d.activeMessage = "";
            return;
        }
    }

    signal showReplyArea(string messageId, string author)


    function startMessageFoundAnimation() {
        if (root.active && root.item.startMessageFoundAnimation) {
            root.item.startMessageFoundAnimation()
        }
    }

    signal openStickerPackPopup(string stickerPackId)
    signal sendViaPersonalChatRequested(string recipientAddress)
    signal tokenPaymentRequested(string recipientAddress, string tokenKey, string rawAmount)

    // Unfurling related requests:
    signal setNeverAskAboutUnfurlingAgain(bool neverAskAgain)

    signal openGifPopupRequest(var params, var cbOnGifSelected, var cbOnClose)

    z: (typeof chatLogView === "undefined") ? 1 : (chatLogView.count - index)

    sourceComponent: {
        if (root.deleted) {
            return deletedMessageComponent
        }
        switch(messageContentType) {
        case Constants.messageContentType.chatIdentifier:
            return channelIdentifierComponent
        case Constants.messageContentType.fetchMoreMessagesButton:
            return fetchMoreMessagesButtonComponent
        case Constants.messageContentType.systemMessagePrivateGroupType: // no break
            return systemMessageGroupComponent
        case Constants.messageContentType.systemMessageMutualEventSent:
        case Constants.messageContentType.systemMessageMutualEventAccepted:
        case Constants.messageContentType.systemMessageMutualEventRemoved:
            return systemMessageMutualEventComponent
        case Constants.messageContentType.systemMessagePinnedMessage:
            return systemMessagePinnedMessageComponent
        case Constants.messageContentType.gapType:
            return gapComponent
        case Constants.messageContentType.newMessagesMarker:
            return newMessagesMarkerComponent
        case Constants.messageContentType.messageType:
        case Constants.messageContentType.stickerType:
        case Constants.messageContentType.emojiType:
        case Constants.messageContentType.transactionType:
        case Constants.messageContentType.imageType:
        case Constants.messageContentType.audioType:
        case Constants.messageContentType.communityInviteType:
        case Constants.messageContentType.discordMessageType:
        case Constants.messageContentType.contactRequestType:
        case Constants.messageContentType.bridgeMessageType:
            return messageComponent
        case Constants.messageContentType.unknownContentType:
            // NOTE: We could display smth like "unknown message type, please upgrade Status to see it".
            return null
        default:
            return null
        }
    }

    QtObject {
        id: d

        readonly property int chatButtonSize: 32
        property bool hideMessage: false
        property bool emojiPopupOpened: false

        property string activeMessage
        readonly property bool isMessageActive: d.activeMessage === root.messageId


        readonly property bool addReactionAllowed: !root.isInPinnedPopup &&
                                                   root.chatContentModule.chatDetails.canPostReactions &&
                                                   !root.isViewMemberMessagesePopup

        readonly property bool canPost: root.chatContentModule.chatDetails.canPost
        readonly property bool canView: canPost || root.chatContentModule.chatDetails.canView

        function getNextMessageHasHeader() {
            if (!root.nextMessageAsJsonObj) {
                return false
            }
            return root.senderId !== root.nextMessageAsJsonObj.senderId ||
                   d.getShouldRepeatHeader(root.nextMessageAsJsonObj.timeStamp, root.messageTimestamp, root.nextMessageAsJsonObj.outgoingStatus) ||
                   root.nextMessageAsJsonObj.responseToMessageWithId !== ""
        }

        function getShouldRepeatHeader(messageTimeStamp, prevMessageTimeStamp, messageOutgoingStatus) {
            return ((messageTimeStamp - prevMessageTimeStamp) / 60 / 1000) > Constants.repeatHeaderInterval
                || d.getIsExpired(messageTimeStamp, messageOutgoingStatus)
        }

        function getIsExpired(messageTimeStamp, messageOutgoingStatus) {
            return (messageOutgoingStatus === Constants.messageOutgoingStatus.sending && (Math.floor(messageTimeStamp) + 180000) < Date.now())
                || messageOutgoingStatus === Constants.expired
        }

        property bool isExpired: false
        property bool shouldRepeatHeader: false
        property bool nextMessageHasHeader: false

        Component.onCompleted: {
            onTimeChanged()
        }

        function onTimeChanged() {
            isExpired = getIsExpired(root.messageTimestamp, root.messageOutgoingStatus)
            shouldRepeatHeader = getShouldRepeatHeader(root.messageTimestamp, root.prevMessageTimestamp, root.messageOutgoingStatus)
            nextMessageHasHeader = getNextMessageHasHeader()
        }

        function convertContentType(value) {
            switch (value) {
            case Constants.messageContentType.contactRequestType:
            case Constants.messageContentType.messageType:
                return StatusMessage.ContentType.Text;
            case Constants.messageContentType.stickerType:
                return StatusMessage.ContentType.Sticker;
            case Constants.messageContentType.emojiType:
                return StatusMessage.ContentType.Emoji;
            case Constants.messageContentType.transactionType:
                return StatusMessage.ContentType.Transaction;
            case Constants.messageContentType.imageType:
                return StatusMessage.ContentType.Image;
            case Constants.messageContentType.audioType:
                return StatusMessage.ContentType.Audio;
            case Constants.messageContentType.communityInviteType:
                return StatusMessage.ContentType.Invitation;
            case Constants.messageContentType.discordMessageType:
                return StatusMessage.ContentType.DiscordMessage;
            case Constants.messageContentType.bridgeMessageType:
                return StatusMessage.ContentType.BridgeMessage;
            case Constants.messageContentType.systemMessagePinnedMessage:
                return StatusMessage.ContentType.SystemMessagePinnedMessage;
            case Constants.messageContentType.systemMessageMutualEventSent:
                return StatusMessage.ContentType.SystemMessageMutualEventSent;
            case Constants.messageContentType.systemMessageMutualEventAccepted:
                return StatusMessage.ContentType.SystemMessageMutualEventAccepted;
            case Constants.messageContentType.systemMessageMutualEventRemoved:
                return StatusMessage.ContentType.SystemMessageMutualEventRemoved;
            case Constants.messageContentType.fetchMoreMessagesButton:
            case Constants.messageContentType.chatIdentifier:
            case Constants.messageContentType.unknownContentType:
            case Constants.messageContentType.statusType:
            case Constants.messageContentType.systemMessagePrivateGroupType:
            case Constants.messageContentType.gapType:
            default:
                return StatusMessage.ContentType.Unknown;
            }
        }

        function convertOutgoingStatus(value) {
            switch (value) {
            case Constants.messageOutgoingStatus.sending:
                return StatusMessage.OutgoingStatus.Sending
            case Constants.messageOutgoingStatus.delivered:
                return StatusMessage.OutgoingStatus.Delivered
            case Constants.messageOutgoingStatus.expired:
                return StatusMessage.OutgoingStatus.Expired
            case Constants.messageOutgoingStatus.failedResending:
                return StatusMessage.OutgoingStatus.FailedResending
            case Constants.messageOutgoingStatus.sent:
            default:
                return StatusMessage.OutgoingStatus.Sent
            }
        }

        function isAbove(mouseArea, mouse, popupH) {
            const p = mouseArea.mapToItem(null, mouse.x, mouse.y)
            const winH = mouseArea.Window.height
            const spaceAbove = p.y
            const spaceBelow = winH - p.y

            // plenty of room below → place below
            if (popupH <= spaceBelow) return false
             // no room below but fits above → place above
            if (popupH <= spaceAbove) return true
            // otherwise pick the side with more space
            return spaceAbove > spaceBelow
        }

        function addReactionClicked(mouseArea, mouse) {
            if (!d.addReactionAllowed || d.emojiPopupOpened) return

            // Don't use mouseArea as parent, as it will be destroyed right after opening menu
            const point = mouseArea.mapToItem(root, mouse.x, mouse.y)
            // Position: put popup next to the click and clamp inside the container
            let x =  point.x - emojiPopup.width
            let y = 0
            if (isAbove(mouseArea, mouse, emojiPopup.height)) {
                y = point.y - emojiPopup.height - Theme.bigPadding
            } else {
                y = point.y + Theme.bigPadding
            }

            emojiPopup.open()
            emojiPopup.directParent = root
            emojiPopup.relativeX = x
            emojiPopup.relativeY = y

            d.emojiPopupOpened = true
        }

        function onImageClicked(image, mouse, imageSource, url = "") {
            switch (mouse.button) {
            case Qt.LeftButton:
                Global.openImagePopup(image, url, false)
                break;
            case Qt.RightButton:
                Global.openMenu(imageContextMenuComponent, image, { imageSource, url })
                break;
            }
        }

        function correctBridgeNameCapitalization(bridgeName) {
            return (bridgeName === "discord") ? "Discord" : bridgeName
        }
    }


    Connections {
        enabled: d.emojiPopupOpened
        target: emojiPopup

        function onEmojiSelected(text: string, atCursor: bool, hexcode: string) {
            root.emojiReactionToggled(root.messageId, hexcode)
        }
        function onClosed() {
            // Debounce so that the popup doesn't immediately reopen when clicking the button
            Backpressure.debounce(root, 100, () => { d.emojiPopupOpened = false })()
        }
    }

    Connections {
        target: StatusSharedUpdateTimer
        function onTriggered() {
            d.onTimeChanged()
        }
    }

    Component {
        id: gapComponent
        GapComponent {
            gapFrom: root.gapFrom
            gapTo: root.gapTo
            onClicked: {
                messageStore.fillGaps(messageId)
                root.visible = false;
                root.height = 0;
            }
        }
    }

    Component {
        id: fetchMoreMessagesButtonComponent
        FetchMoreMessagesButton {
            nextMessageIndex: root.nextMessageIndex
            nextMsgTimestamp: root.nextMessageTimestamp
            onTimerTriggered: {
                messageStore.requestMoreMessages();
            }
        }
    }

    Component {
        id: channelIdentifierComponent
        ChannelIdentifierView {
            chatName: root.senderDisplayName
            chatId: root.messageStore.getChatId()
            chatType: root.messageStore.chatType
            chatColor: root.messageStore.chatColor
            chatEmoji: root.channelEmoji
            amIChatAdmin: root.amIChatAdmin
            chatIcon: {
                if (root.messageStore.chatType === Constants.chatType.privateGroupChat &&
                        root.messageStore.chatIcon !== "") {
                    return root.messageStore.chatIcon
                }
                return root.senderIcon
            }
        }
    }

    Component {
        id: systemMessageGroupComponent

        StyledText {
            wrapMode: Text.Wrap

            readonly property string systemMessageText: root.messageText.length > 0 ? root.messageText : root.unparsedText
            text: {
                return `<html>`+
                        `<head>`+
                        `<style type="text/css">`+
                        `a {`+
                        `color: ${Theme.palette.textColor};`+
                        `text-decoration: none;`+
                        `}`+
                        `</style>`+
                        `</head>`+
                        `<body>`+
                        `${systemMessageText}`+
                        `</body>`+
                        `</html>`;
            }
            color: Theme.palette.secondaryText
            font.pixelSize: Theme.secondaryTextFontSize
            width: parent.width - 120
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.RichText
            topPadding: root.prevMessageIndex === 1 ? Theme.bigPadding : 0
        }
    }

    Component{
        id: systemMessageMutualEventComponent

        StyledText {
            property var chatContactModelEntry: ContactModelEntry {
                publicKey: chatId
                contactsModel: root.rootStore.contactsModel
                onPopulateContactDetailsRequested: root.rootStore.populateContactDetailsRequested(chatId)
            }

            text: {
                var displayName = root.amISender ? chatContactModelEntry.contactDetails.displayName : root.senderDisplayName
                switch (root.messageContentType) {
                    case Constants.messageContentType.systemMessageMutualEventSent:
                        return root.amISender ?
                            qsTr("You sent a contact request to %1").arg(displayName) :
                            qsTr("%1 sent you a contact request").arg(displayName)
                    case Constants.messageContentType.systemMessageMutualEventAccepted:
                        return root.amISender ?
                            qsTr("You accepted %1's contact request").arg(displayName) :
                            qsTr("%1 accepted your contact request").arg(displayName)
                    case Constants.messageContentType.systemMessageMutualEventRemoved:
                        return root.amISender ?
                            qsTr("You removed %1 as a contact").arg(displayName) :
                            qsTr("%1 removed you as a contact").arg(displayName)
                    default:
                        return root.messageText
                }
            }
            color: Theme.palette.secondaryText
            font.pixelSize: Theme.secondaryTextFontSize
            width: parent.width - 120
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.RichText
            topPadding: root.prevMessageIndex === 1 ? Theme.bigPadding : 0
        }
    }

    Component {
        id: systemMessagePinnedMessageComponent

        StatusBaseText {
            width: parent.width - 120
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("%1 pinned a message").arg(senderDisplayName)
            color: Theme.palette.directColor3
            font.family: Fonts.baseFont.family
            font.pixelSize: Theme.primaryTextFontSize
            textFormat: Text.RichText
            wrapMode: Text.Wrap
            topPadding: root.prevMessageIndex === 1 ? Theme.bigPadding : 0
        }
    }

    Component {
        id: deletedMessageComponent

        ColumnLayout {

            RowLayout {
                id: deletedMessage
                height: 40
                Layout.fillWidth: true
                Layout.topMargin: Theme.halfPadding
                Layout.bottomMargin: Theme.halfPadding
                Layout.leftMargin: Theme.padding
                spacing: Theme.halfPadding

                readonly property int smartIconSize: 20
                readonly property int colorId: Utils.colorIdForPubkey(root.deletedBy)
                readonly property var messageDetails: StatusMessageDetails {
                    sender.profileImage {
                        width: deletedMessage.smartIconSize
                        height: deletedMessage.smartIconSize
                        assetSettings: StatusAssetSettings {
                            width: deletedMessage.smartIconSize
                            height: deletedMessage.smartIconSize
                            name: root.deletedByContactIcon || ""
                            isLetterIdenticon: name === ""
                            imgIsIdenticon: false
                            charactersLen: 1
                            color: root.Theme.palette.userCustomizationColors[deletedMessage.colorId]
                            letterSize: 14
                        }

                        name: root.deletedByContactIcon || ""
                        pubkey: root.deletedBy
                        color: root.Theme.palette.userCustomizationColors[deletedMessage.colorId]
                    }
                }

                Rectangle {
                    Layout.preferredWidth: deletedMessage.height
                    Layout.preferredHeight: deletedMessage.height

                    radius: width / 2
                    color: Theme.palette.dangerColor3
                    Layout.alignment: Qt.AlignVCenter

                    StatusIcon {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        icon: "delete"
                        color: Theme.palette.dangerColor1
                    }
                }

                StatusSmartIdenticon {
                    id: profileImage
                    Layout.preferredWidth: deletedMessage.smartIconSize
                    Layout.preferredHeight: deletedMessage.smartIconSize
                    Layout.alignment: Qt.AlignVCenter
                    visible: true
                    name: root.deletedByContactDisplayName
                    asset: deletedMessage.messageDetails.sender.profileImage.assetSettings
                }

                StatusBaseText {
                    text: qsTr("<b>%1</b> deleted this message").arg(root.deletedByContactDisplayName)
                    Layout.alignment: Qt.AlignVCenter
                }

                StatusTimeStampLabel {
                    Layout.alignment: Qt.AlignVCenter
                    timestamp: root.messageTimestamp
                }
            }
        }
    }

    Component {
        id: messageComponent

        ColumnLayout {
            spacing: 0

            function startMessageFoundAnimation() {
                delegate.startMessageFoundAnimation();
            }

            StatusDateGroupLabel {
                id: dateGroupLabel
                Layout.fillWidth: true
                Layout.topMargin: Theme.padding
                Layout.bottomMargin: Theme.padding
                messageTimestamp: root.messageTimestamp
                previousMessageTimestamp: root.prevMessageIndex === -1 ? 0 : root.prevMessageTimestamp
                visible: text !== "" && !root.isInPinnedPopup && !root.isViewMemberMessagesePopup
            }

            StatusMessage {
                id: delegate
                Layout.fillWidth: true
                Layout.topMargin: showHeader && !root.isInPinnedPopup ? 2 : 0
                Layout.bottomMargin: !root.isInPinnedPopup ? 2 : 0

                readonly property int contentType: d.convertContentType(root.messageContentType)
                property string originalMessageText: ""
                readonly property bool hideQuickActions: {
                    return root.isChatBlocked ||
                                  root.placeholderMessage ||
                                  root.isInPinnedPopup ||
                                  root.editModeOn ||
                                  !root.joined
                }

                function editCancelledHandler() {
                    root.messageStore.setEditModeOff(root.messageId)
                }

                function editCompletedHandler(newMessageText) {

                    if (delegate.originalMessageText === newMessageText) {
                        delegate.editCancelledHandler()
                        return
                    }

                    const message = StatusQUtils.StringUtils.plainText(StatusQUtils.Emoji.deparse(newMessageText))

                    if (message.length <= 0)
                        return;

                    root.unparsedText = message

                    const interpretedMessage = root.messageStore.interpretMessage(message)
                    root.messageStore.setEditModeOff(root.messageId)
                    root.messageStore.editMessage(
                        root.messageId,
                        interpretedMessage
                    )
                }

                pinnedMsgInfoText: root.isDiscordMessage ? qsTr("Pinned") : qsTr("Pinned by")

                timestamp: root.messageTimestamp
                editMode: root.editModeOn
                isAReply: root.responseToMessageWithId !== ""
                isEdited: root.isEdited
                hasMention: root.hasMention
                isPinned: root.pinnedMessage
                pinnedBy: {
                    if (!root.pinnedMessage || root.isDiscordMessage || !root.messagePinnedByContactEntryLoader.active)
                        return ""
                    const contact = root.messagePinnedByContactEntryLoader.item.contactDetails
                    return ProfileUtils.displayName(contact.localNickname, contact.name, contact.displayName, contact.alias)
                }
                isInPinnedPopup: root.isInPinnedPopup
                outgoingStatus: d.isExpired ? StatusMessage.OutgoingStatus.Expired
                                            : d.convertOutgoingStatus(messageOutgoingStatus)

                resendError: root.resendError
                reactionsModel: root.reactionsModel
                maxEmojiReactionsPerMessage: Constants.maxEmojiReactionsPerMessage
                linkPreviewModel: root.linkPreviewModel
                paymentRequestModel: root.paymentRequestModel
                gifLinks: root.gifLinks

                showHeader: root.shouldRepeatHeader || dateGroupLabel.visible || isAReply ||
                            root.prevMessageContentType === Constants.messageContentType.systemMessagePrivateGroupType ||
                            root.prevMessageContentType === Constants.messageContentType.systemMessagePinnedMessage ||
                            root.prevMessageContentType === Constants.messageContentType.systemMessageMutualEventSent ||
                            root.prevMessageContentType === Constants.messageContentType.systemMessageMutualEventAccepted ||
                            root.prevMessageContentType === Constants.messageContentType.systemMessageMutualEventRemoved ||
                            root.prevMessageContentType === Constants.messageContentType.bridgeMessageType ||
                            root.senderId !== root.prevMessageSenderId || root.prevMessageDeleted
                isActiveMessage: d.isMessageActive
                topPadding: showHeader ? Theme.halfPadding : 0
                bottomPadding: showHeader && d.nextMessageHasHeader ? Theme.halfPadding : 2
                disableHover: root.disableHover ||
                              (delegate.hideQuickActions && !d.addReactionAllowed) ||
                              (root.chatLogView && root.chatLogView.moving)

                disableEmojis: !d.addReactionAllowed
                hideMessage: d.hideMessage
                linkAddressAndEnsName: root.sendViaPersonalChatEnabled
                disabledTooltipText: root.disabledTooltipText

                overrideBackground: root.placeholderMessage
                profileClickable: !root.isDiscordMessage
                messageAttachments: root.messageAttachments

                onEditCancelled: {
                    delegate.editCancelledHandler()
                }

                onEditCompleted: delegate.editCompletedHandler(newMsgText)

                onImageClicked: (image, mouse, imageSource) => {
                    d.onImageClicked(image, mouse, imageSource)
                }

                onLinkActivated: link => {
                    if (link.startsWith(Constants.sendViaChatPrefix)) {
                        const addressOrEns = link.replace(Constants.sendViaChatPrefix, "");
                        root.sendViaPersonalChatRequested(addressOrEns)
                        return
                    }
                    if (link.startsWith('//')) {
                        const pubkey = link.replace("//", "");
                        Global.openProfilePopup(pubkey)
                        return
                    }
                    if (link.startsWith('#')) {
                        rootStore.chatCommunitySectionModule.switchToChannel(link.replace("#", ""))
                        return
                    }

                    const linkPreviewType = root.linkPreviewModel.getLinkPreviewType(link)

                    if (linkPreviewType === Constants.LinkPreviewType.Standard || !Utils.isStatusDeepLink(link)) {
                        Global.requestOpenLink(link)
                        return
                    }

                    Global.activateDeepLink(link)
                }

                onProfilePictureClicked: (sender, mouse) => root.openProfileContextMenu(mouse.x, mouse.y)
                onReplyProfileClicked: (sender, mouse) => root.openProfileContextMenu(mouse.x, mouse.y, true)
                onReplyMessageClicked: (mouse) => root.messageStore.messageModule.jumpToMessage(root.responseToMessageWithId)
                onSenderNameClicked: (sender) => root.openProfileContextMenu(sender.x, sender.y)

                onToggleReactionClicked: (hexcode) => {
                    if (root.isChatBlocked)
                        return

                    if (!root.messageStore) {
                        console.error("Reaction can not be toggled, message store is not valid")
                        return
                    }

                    root.emojiReactionToggled(root.messageId, hexcode)
                }

                onAddReactionClicked: (sender, mouse) => {
                    d.addReactionClicked(sender, mouse)
                }

                onStickerClicked: {
                    root.openStickerPackPopup(root.stickerPack);
                }

                onResendClicked: {
                    root.messageStore.resendMessage(root.messageId)
                }

                ContextMenu.onRequested: pos => root.openMessageContextMenu(pos.x, pos.y)
                onPressAndHold: function (mouse) {
                    if (mouse.wasHeld && (root.chatLogView && !root.chatLogView.moving))
                        root.openMessageContextMenu(mouse.x, mouse.y)
                }

                messageDetails: StatusMessageDetails {
                    contentType: delegate.contentType
                    messageOriginInfo: {
                        if (isDiscordMessage)  {
                            return qsTr("Imported from discord")
                        } else if (isBridgeMessage) {
                            return qsTr("Bridged from %1").arg(d.correctBridgeNameCapitalization(root.bridgeName))
                        }
                        return ""
                    }
                    messageText: root.messageText
                    messageContent: {
                        switch (delegate.contentType)
                        {
                        case StatusMessage.ContentType.Sticker:
                            return root.sticker;
                        case StatusMessage.ContentType.Image:

                            return root.messageImage;
                        }
                        if (root.isDiscordMessage && root.messageImage != "") {
                            return root.messageImage
                        }
                        return "";
                    }
                    album: root.album
                    albumCount: root.albumCount

                    amISender: root.amISender
                    sender.id: root.senderIsEnsVerified ? "" : root.compressedKey
                    sender.displayName: root.senderDisplayName
                    sender.usesDefaultName: root.usesDefaultName
                    sender.secondaryName: root.senderOptionalName
                    sender.isEnsVerified: root.isBridgeMessage ? false : root.senderIsEnsVerified
                    sender.isContact: root.isBridgeMessage ? false : root.senderIsAdded
                    sender.trustIndicator: root.isBridgeMessage ? StatusContactVerificationIcons.TrustedType.None: root.senderTrustStatus
                    sender.profileImage {
                        width: 40
                        height: 40
                        name: root.senderIcon || ""
                        pubkey: root.senderId
                        color: root.Theme.palette.userCustomizationColors[Utils.colorIdForPubkey(root.senderId)]
                    }
                    sender.badgeImage: Assets.svg("discord-bridge")
                }

                replyDetails: StatusMessageDetails {
                    readonly property var responseMessage: contentType === StatusMessage.ContentType.Sticker || contentType === StatusMessage.ContentType.Image
                                                           ? root.messageStore.getMessageByIdAsJson(responseToMessageWithId)
                                                           : null
                    onResponseMessageChanged: {
                        if (!responseMessage)
                            return

                        switch (contentType) {
                        case StatusMessage.ContentType.Sticker:
                            messageContent = responseMessage.sticker;
                            return
                        case StatusMessage.ContentType.Image:
                            messageContent = responseMessage.messageImage;
                            albumCount = responseMessage.albumImagesCount
                            album = responseMessage.albumMessageImages
                            return
                        default:
                            messageContent = ""
                        }
                    }

                    messageText: {
                        if (messageDeleted)
                            return qsTr("Message deleted")
                        if (!root.quotedMessageText && !root.quotedMessageFrom)
                            return qsTr("Unknown message. Try fetching more messages")
                        return root.quotedMessageText
                    }
                    album: root.quotedMessageAlbumMessageImages
                    albumCount: root.quotedMessageAlbumImagesCount
                    messageDeleted: root.quotedMessageDeleted
                    contentType: d.convertContentType(root.quotedMessageContentType)
                    amISender: root.quotedMessageFrom === userProfile.pubKey
                    sender.id: root.quotedMessageFrom
                    sender.isContact: quotedMessageAuthorDetailsIsContact
                    sender.displayName: quotedMessageAuthorDetailsDisplayName
                    sender.isEnsVerified: quotedMessageAuthorDetailsEnsVerified
                    sender.secondaryName: quotedMessageAuthorDetailsName
                    sender.profileImage {
                        width: 20
                        height: 20
                        name: quotedMessageAuthorDetailsThumbnailImage
                        assetSettings.isImage: quotedMessageAuthorDetailsThumbnailImage
                        pubkey: sender.id
                        color: root.Theme.palette.userCustomizationColors[Utils.colorIdForPubkey(sender.id)]
                    }
                }

                statusChatInput: Component {
                    StatusChatInput {
                        id: editTextInput
                        objectName: "editMessageInput"

                        readonly property string messageText: editTextInput.textInput.text

                        // TODO: Move this property and Escape handler to StatusChatInput
                        property bool suggestionsOpened: false

                        width: parent.width

                        Keys.onEscapePressed: {
                            if (!suggestionsOpened) {
                                delegate.editCancelled()
                            }
                            suggestionsOpened = false
                        }

                        usersModel: root.usersModel
                        emojiPopup: root.emojiPopup
                        stickersPopup: root.stickersPopup

                        chatType: root.messageStore.chatType
                        isEdit: true

                        onSendMessage: delegate.editCompletedHandler(editTextInput.getTextWithPublicKeys())
                        onOpenGifPopupRequest: (params, cbOnGifSelected, cbOnClose) => root.openGifPopupRequest(params, cbOnGifSelected, cbOnClose)

                        Component.onCompleted: {
                            parseMessage(root.messageText);
                            delegate.originalMessageText = editTextInput.textInput.text
                        }
                    }
                }

                linksComponent: Component {
                    LinksMessageView {
                        id: linksMessageView

                        linkPreviewModel: root.linkPreviewModel
                        gifLinks: root.gifLinks
                        senderName: root.senderDisplayName
                        senderThumbnailImage: root.senderIcon || ""
                        senderColorId: Utils.colorIdForPubkey(root.senderId)
                        paymentRequestModel: root.paymentRequestModel
                        playAnimations: root.Window.active && root.messageStore.isChatActive
                        isOnline: root.messageStore.isOnline
                        highlightLink: delegate.hoveredLink
                        areTestNetworksEnabled: root.areTestNetworksEnabled
                        formatBalance: root.formatBalance
                        onImageClicked: (image, mouse, imageSource, url) => {
                            d.onImageClicked(image, mouse, imageSource, url)
                        }
                        onOpenContextMenu: (item, url, domain) => {
                            Global.openMenu(imageContextMenuComponent, item, { url: url, domain: domain })
                        }
                        onHoveredLinkChanged: delegate.highlightedLink = linksMessageView.hoveredLink
                        gifUnfurlingEnabled: root.gifUnfurlingEnabled
                        canAskToUnfurlGifs: !root.neverAskAboutUnfurlingAgain
                        onSetNeverAskAboutUnfurlingAgain: root.setNeverAskAboutUnfurlingAgain(neverAskAgain)
                        onPaymentRequestClicked: (index) => {
                            const request = StatusQUtils.ModelUtils.get(paymentRequestModel, index)
                            root.tokenPaymentRequested(request.receiver, request.tokenKey, request.amount)
                        }

                        Component.onCompleted: {
                            root.messageStore.messageModule.forceLinkPreviewsLocalData(root.messageId)
                        }
                    }
                }

                invitationComponent: Component {
                    InvitationBubbleView {
                        store: root.rootStore
                        communityId: root.communityId

                        onSpectateCommunityRequested: (communityId) => {
                            root.spectateCommunityRequested(communityId)
                        }
                    }
                }

                quickActions: [
                    MessageReactionsRow {
                        visible: {
                            root.emojiReactionLimitReached
                            return !root.emojiReactionLimitReached && !root.isViewMemberMessagesePopup
                        }
                        buttonSize: d.chatButtonSize
                        leftPadding: 0
                        rightPadding: 0
                        emojiModel: emojiPopup.fullModel
                        onToggleReaction: hexcode => root.emojiReactionToggled(root.messageId, hexcode)
                        onOpenEmojiPopup: (parent, mouse) => {
                            d.addReactionClicked(parent, mouse)
                        }
                    },
                    Loader {
                        active: !root.isInPinnedPopup && delegate.hovered && !delegate.hideQuickActions
                                && !root.isViewMemberMessagesePopup && d.canPost
                        visible: active
                        sourceComponent: StatusFlatRoundButton {
                            objectName: "replyToMessageButton"
                            width: d.chatButtonSize
                            height: d.chatButtonSize
                            icon.name: "reply"
                            type: StatusFlatRoundButton.Type.Tertiary
                            tooltip.text: qsTr("Reply")
                            onClicked: {
                                root.showReplyArea(root.messageId, root.senderId)
                            }
                        }
                    },
                    Loader {
                        active: {

                            return !root.isInPinnedPopup && !root.editRestricted && !root.editModeOn && root.amISender && delegate.hovered && !delegate.hideQuickActions
                                && !root.isViewMemberMessagesePopup && d.canPost
                        }
                        visible: active
                        sourceComponent: StatusFlatRoundButton {
                            objectName: "editMessageButton"
                            width: d.chatButtonSize
                            height: d.chatButtonSize
                            icon.name: "edit_pencil"
                            type: StatusFlatRoundButton.Type.Tertiary
                            tooltip.text: qsTr("Edit")
                            onClicked: {
                                root.messageStore.setEditModeOn(root.messageId)
                            }
                        }
                    },
                    Loader {
                        active: {
                            if(!delegate.hovered)
                                return false;

                            if (!root.messageStore)
                                return false

                            if(delegate.hideQuickActions)
                                return false;

                            if (!d.canPost)
                                return false;

                            if (root.isViewMemberMessagesePopup) {
                                return false
                            }

                            const chatType = root.messageStore.chatType;
                            const pinMessageAllowedForMembers = root.messageStore.isPinMessageAllowedForMembers

                            return chatType === Constants.chatType.oneToOne ||
                                    chatType === Constants.chatType.privateGroupChat && root.amIChatAdmin ||
                                    chatType === Constants.chatType.communityChat && (root.amIChatAdmin || pinMessageAllowedForMembers);

                        }
                        visible: active
                        sourceComponent: StatusFlatRoundButton {
                            objectName: "MessageView_toggleMessagePin"
                            width: d.chatButtonSize
                            height: d.chatButtonSize
                            icon.name: root.pinnedMessage ? "unpin" : "pin"
                            type: StatusFlatRoundButton.Type.Tertiary
                            tooltip.text: root.pinnedMessage ? qsTr("Unpin") : qsTr("Pin")
                            onClicked: {
                                if (root.pinnedMessage) {
                                    messageStore.unpinMessage(root.messageId)
                                    return;
                                }

                                if (!!root.messageStore && root.messageStore.getNumberOfPinnedMessages() < Constants.maxNumberOfPins) {
                                    messageStore.pinMessage(root.messageId)
                                    return;
                                }

                                if (!chatContentModule) {
                                    console.warn("error on open pinned messages limit reached from message context menu - chat content module is not set")
                                    return;
                                }

                                const chatId = root.messageStore.chatType === Constants.chatType.oneToOne ? chatContentModule.getMyChatId() : ""
                                Global.openPinnedMessagesPopupRequested(root.rootStore, messageStore, chatContentModule.pinnedMessagesModel, root.messageId, chatId)
                            }
                        }
                    },
                    Loader {
                        active: !root.editModeOn && delegate.hovered && !delegate.hideQuickActions && !root.isViewMemberMessagesePopup
                        visible: active
                        sourceComponent: StatusFlatRoundButton {
                            objectName: "markAsUnreadButton"
                            width: d.chatButtonSize
                            height: d.chatButtonSize
                            icon.name: "hide"
                            type: StatusFlatRoundButton.Type.Tertiary
                            tooltip.text: qsTr("Mark as unread")
                            onClicked: {
                                root.messageStore.markMessageAsUnread(root.messageId)
                            }
                        }
                    },
                    Loader {
                        active: {
                            if(!delegate.hovered)
                                return false;
                            if (root.isInPinnedPopup)
                                return false;
                            if (!root.messageStore)
                                return false;
                            if (delegate.hideQuickActions)
                                return false;
                            if (!d.canPost)
                                return false;
                            return (root.amISender || root.amIChatAdmin) &&
                                    (messageContentType === Constants.messageContentType.messageType ||
                                     messageContentType === Constants.messageContentType.stickerType ||
                                     messageContentType === Constants.messageContentType.emojiType ||
                                     messageContentType === Constants.messageContentType.imageType ||
                                     messageContentType === Constants.messageContentType.audioType);
                        }
                        visible: active
                        sourceComponent: StatusFlatRoundButton {
                            objectName: "chatDeleteMessageButton"
                            width: d.chatButtonSize
                            height: d.chatButtonSize
                            icon.name: "delete"
                            type: StatusFlatRoundButton.Type.Tertiary
                            tooltip.text: qsTr("Delete")
                            onClicked: root.isViewMemberMessagesePopup
                                       ? root.chatCommunitySectionModule.deleteCommunityMemberMessages(root.senderId, root.messageId, root.chatId)
                                       : messageStore.warnAndDeleteMessage(root.messageId)
                        }
                    }
                ]
            }
        }
    }

    Component {
        id: newMessagesMarkerComponent

        NewMessagesMarker {
            count: root.messageStore.newMessagesCount
            timestamp: root.messageTimestamp
        }
    }

    Component {
        id: imageContextMenuComponent

        ImageContextMenu {
            onClosed: {
                destroy()
            }
        }
    }

    Component {
        id: profileContextMenuComponent
        ProfileContextMenu {
            id: profileContextMenu

            property string pubKey

            onOpenProfileClicked: Global.openProfilePopup(profileContextMenu.pubKey, null)
            onCreateOneToOneChat: () => {
                Global.changeAppSectionBySectionType(Constants.appSection.chat)
                root.rootStore.chatCommunitySectionModule.createOneToOneChat("", profileContextMenu.pubKey, "")
            }
            onReviewContactRequest: Global.openReviewContactRequestPopup(profileContextMenu.pubKey, null)
            onSendContactRequest: Global.openContactRequestPopup(profileContextMenu.pubKey, null)
            onEditNickname: Global.openNicknamePopupRequested(profileContextMenu.pubKey, null)
            onRemoveNickname: root.changeContactNicknameRequest(profileContextMenu.pubKey,
                                                                  "", profileContextMenu.displayName, true)
            onUnblockContact: Global.unblockContactRequested(profileContextMenu.pubKey)
            onMarkAsUntrusted: Global.markAsUntrustedRequested(profileContextMenu.pubKey)
            onRemoveTrustStatus: root.removeTrustStatusRequest(profileContextMenu.pubKey)
            onRemoveContact: Global.removeContactRequested(profileContextMenu.pubKey)
            onBlockContact: Global.blockContactRequested(profileContextMenu.pubKey)
            onRemoveFromGroup: root.rootStore.removeMemberFromGroupChat(profileContextMenu.pubKey)
            onMarkAsTrusted: Global.openMarkAsIDVerifiedPopup(profileContextMenu.pubKey, null)
            onRemoveTrustedMark: Global.openRemoveIDVerificationDialog(profileContextMenu.pubKey, null)

            onOpened: root.setMessageActive(root.messageId, true)
            onClosed: {
                root.setMessageActive(root.messageId, false)
                destroy()
            }
        }
    }
    Component {
        id: messageContextMenuComponent

        MessageContextMenuView {
            id: messageContextMenuView
            emojiReactionLimitReached: root.emojiReactionLimitReached
            emojiModel: emojiPopup.fullModel
            disabledForChat: !root.rootStore.isUserAllowedToSendMessage
            forceEnableEmojiReactions: !root.rootStore.isUserAllowedToSendMessage && d.addReactionAllowed
            isDebugEnabled: root.rootStore && root.rootStore.isDebugEnabled
            onPinMessage: root.messageStore.pinMessage(messageContextMenuView.messageId)
            onUnpinMessage: root.messageStore.unpinMessage(messageContextMenuView.messageId)
            onPinnedMessagesLimitReached: () => {
                if (!root.chatContentModule) {
                    console.warn("error on open pinned messages limit reached from message context menu - chat content module is not set")
                    return
                }
                Global.openPinnedMessagesPopupRequested(root.rootStore,
                                                        root.messageStore,
                                                        root.chatContentModule.pinnedMessagesModel,
                                                        messageContextMenuView.messageId,
                                                        root.chatId)
            }
            onMarkMessageAsUnread: root.messageStore.markMessageAsUnread(messageContextMenuView.messageId)
            onToggleReaction: (hexcode) => root.emojiReactionToggled(root.messageId, hexcode)
            onDeleteMessage: root.messageStore.warnAndDeleteMessage(messageContextMenuView.messageId)
            onEditClicked: root.messageStore.setEditModeOn(messageContextMenuView.messageId)
            onShowReplyArea: (senderId) => {
                root.showReplyArea(messageContextMenuView.messageId, senderId)
            }
            onCopyToClipboard: (text) => {
                ClipboardUtils.setText(text)
            }
            onOpenEmojiPopup: (parent, mouse) => d.addReactionClicked(parent, mouse)
            onOpened: {
                root.setMessageActive(model.id, true)
            }
            onClosed: {
                root.setMessageActive(model.id, false)
                destroy()
            }
        }
    }
}
