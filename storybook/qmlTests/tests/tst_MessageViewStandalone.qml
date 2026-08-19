import QtQuick
import QtTest

import utils

import shared.views.chat

import StatusQ.Components
import StatusQ.Core.Theme

import AppLayouts.Chat.stores as ChatStores

/*
 Row-pool contract (issue 0001): MessageView must construct with zero data
 and no model/delegate context, and reassigning the full property set must
 retarget it to a different message with no residue from the previous one —
 the rebind IS the reset, there is no separate clear step.
*/
Item {
    id: root

    width: 800
    height: 600

    ListModel {
        id: contactsModel

        function hasUser(pubKey) {
            for (let i = 0; i < count; ++i) {
                if (get(i).pubKey === pubKey)
                    return true
            }
            return false
        }

        Component.onCompleted: {
            append({
                pubKey: "0xpinner",
                displayName: "Pinner Contact",
                preferredDisplayName: "Pinner Contact",
                name: "",
                ensName: "",
                isEnsVerified: false,
                localNickname: "",
                alias: "",
                icon: "",
                colorId: 1,
                onlineStatus: 1,
                isContact: true,
                isVerified: false,
                isUntrustworthy: false,
                isBlocked: false,
                contactRequest: 2,
                isCurrentUser: false,
                lastUpdated: 1,
                lastUpdatedLocally: 1,
                bio: "",
                thumbnailImage: "",
                largeImage: "",
                isContactRequestReceived: false,
                isContactRequestSent: false,
                isRemoved: false,
                trustStatus: 0,
                usesDefaultName: false,
                compressedPubKey: "zQpinner"
            })
        }
    }

    ChatStores.RootStore {
        id: rootStoreMock

        property var contactsModel: contactsModel

        function populateContactDetailsRequested(pubKey) {}
    }

    ChatStores.MessageStore {
        id: messageStoreMock

        // resolved originals for replies, keyed by message id
        property var messagesById: ({})

        function getMessageByIdAsJson(id) {
            return messagesById[id] ?? null
        }
    }

    QtObject {
        id: chatContentModuleMock

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property int type: Constants.chatType.oneToOne
            readonly property bool canPostReactions: true
            readonly property bool canPost: true
            readonly property bool canView: true
        }
    }

    ListModel { id: reactionsA }
    ListModel { id: reactionsB }

    Component {
        id: fontWarmupComp

        Text {
            text: "font warmup"
            textFormat: Text.RichText
            font.family: "Sans Serif"
        }
    }

    Component {
        id: bareMessageViewComp

        MessageView {
            width: 600
        }
    }

    Component {
        id: storedMessageViewComp

        MessageView {
            width: 600

            rootStore: rootStoreMock
            messageStore: messageStoreMock
            chatContentModule: chatContentModuleMock
            joined: true
        }
    }

    TestCase {
        name: "MessageViewStandalone"
        when: windowShown

        // Repo-local photos: image content must not hit the network and must
        // exist in any checkout
        readonly property string photoA: Assets.png("chat/chat@2x")
        readonly property string photoB: Assets.png("chat/request_payment_banner")

        // Full per-message property set, mirroring what the chat shell (and
        // later the pool's RowBinder) assigns. Every rebind writes every key.
        readonly property var messageA: ({
            messageId: "msg-a",
            communityId: "",
            responseToMessageWithId: "orig-img",
            senderId: "0xalice",
            senderDisplayName: "Alice",
            usesDefaultName: false,
            senderOptionalName: "",
            senderIsEnsVerified: false,
            senderIcon: "",
            senderIsAdded: true,
            senderTrustStatus: 0,
            compressedKey: "zQalice",
            amISender: false,
            messageText: "alpha message text",
            unparsedText: "alpha message text",
            messageImage: "",
            album: [],
            albumCount: 0,
            messageTimestamp: Date.now() - 10 * 60 * 1000,
            messageOutgoingStatus: "sending",
            resendError: "",
            messageContentType: Constants.messageContentType.messageType,
            pinnedMessage: true,
            messagePinnedBy: "0xpinner",
            reactionsModel: reactionsA,
            sticker: "",
            stickerPack: -1,
            editModeOn: false,
            isEdited: true,
            deleted: false,
            deletedBy: "",
            deletedByContactDisplayName: "",
            deletedByContactIcon: "",
            linkPreviewModel: null,
            links: "",
            paymentRequestModel: null,
            messageAttachments: "",
            hasMention: true,
            quotedMessageText: "quoted A",
            quotedMessageUnparsedText: "quoted A",
            quotedMessageFrom: "0xpinner",
            quotedMessageContentType: Constants.messageContentType.imageType,
            quotedMessageDeleted: false,
            quotedMessageAuthorDetailsName: "",
            quotedMessageAuthorDetailsDisplayName: "Pinner Contact",
            quotedMessageAuthorDetailsThumbnailImage: "",
            quotedMessageAuthorDetailsEnsVerified: false,
            quotedMessageAuthorDetailsIsContact: true,
            quotedMessageAlbumMessageImages: [],
            quotedMessageAlbumImagesCount: 0,
            bridgeName: "",
            gapFrom: 0,
            gapTo: 0,
            prevMessageIndex: -1,
            prevMessageTimestamp: 0,
            prevMessageSenderId: "",
            prevMessageContentType: Constants.messageContentType.unknownContentType,
            prevMessageDeleted: false,
            nextMessageIndex: -1,
            nextMessageTimestamp: 0,
            mentionsMap: ({})
        })

        readonly property var messageB: ({
            messageId: "msg-b",
            communityId: "",
            responseToMessageWithId: "",
            senderId: "0xbob",
            senderDisplayName: "Bob",
            usesDefaultName: false,
            senderOptionalName: "",
            senderIsEnsVerified: false,
            senderIcon: "",
            senderIsAdded: false,
            senderTrustStatus: 0,
            compressedKey: "zQbob",
            amISender: true,
            messageText: "bravo message text",
            unparsedText: "bravo message text",
            messageImage: "",
            album: [],
            albumCount: 0,
            messageTimestamp: Date.now(),
            messageOutgoingStatus: "sent",
            resendError: "",
            messageContentType: Constants.messageContentType.messageType,
            pinnedMessage: false,
            messagePinnedBy: "",
            reactionsModel: reactionsB,
            sticker: "",
            stickerPack: -1,
            editModeOn: false,
            isEdited: false,
            deleted: false,
            deletedBy: "",
            deletedByContactDisplayName: "",
            deletedByContactIcon: "",
            linkPreviewModel: null,
            links: "",
            paymentRequestModel: null,
            messageAttachments: "",
            hasMention: false,
            quotedMessageText: "",
            quotedMessageUnparsedText: "",
            quotedMessageFrom: "",
            quotedMessageContentType: Constants.messageContentType.messageType,
            quotedMessageDeleted: false,
            quotedMessageAuthorDetailsName: "",
            quotedMessageAuthorDetailsDisplayName: "",
            quotedMessageAuthorDetailsThumbnailImage: "",
            quotedMessageAuthorDetailsEnsVerified: false,
            quotedMessageAuthorDetailsIsContact: false,
            quotedMessageAlbumMessageImages: [],
            quotedMessageAlbumImagesCount: 0,
            bridgeName: "",
            gapFrom: 0,
            gapTo: 0,
            prevMessageIndex: -1,
            prevMessageTimestamp: 0,
            prevMessageSenderId: "",
            prevMessageContentType: Constants.messageContentType.unknownContentType,
            prevMessageDeleted: false,
            nextMessageIndex: -1,
            nextMessageTimestamp: 0,
            mentionsMap: ({})
        })

        // Reply whose original is NOT loaded; quoted album comes from the
        // quoted payload roles instead
        readonly property var messageC: ({
            messageId: "msg-c",
            communityId: "",
            responseToMessageWithId: "orig-missing",
            senderId: "0xcarol",
            senderDisplayName: "Carol",
            usesDefaultName: false,
            senderOptionalName: "",
            senderIsEnsVerified: false,
            senderIcon: "",
            senderIsAdded: false,
            senderTrustStatus: 0,
            compressedKey: "zQcarol",
            amISender: false,
            messageText: "charlie message text",
            unparsedText: "charlie message text",
            messageImage: "",
            album: [],
            albumCount: 0,
            messageTimestamp: Date.now(),
            messageOutgoingStatus: "sent",
            resendError: "",
            messageContentType: Constants.messageContentType.messageType,
            pinnedMessage: false,
            messagePinnedBy: "",
            reactionsModel: null,
            sticker: "",
            stickerPack: -1,
            editModeOn: false,
            isEdited: false,
            deleted: false,
            deletedBy: "",
            deletedByContactDisplayName: "",
            deletedByContactIcon: "",
            linkPreviewModel: null,
            links: "",
            paymentRequestModel: null,
            messageAttachments: "",
            hasMention: false,
            quotedMessageText: "quoted C",
            quotedMessageUnparsedText: "quoted C",
            quotedMessageFrom: "0xpinner",
            quotedMessageContentType: Constants.messageContentType.imageType,
            quotedMessageDeleted: false,
            quotedMessageAuthorDetailsName: "",
            quotedMessageAuthorDetailsDisplayName: "Pinner Contact",
            quotedMessageAuthorDetailsThumbnailImage: "",
            quotedMessageAuthorDetailsEnsVerified: false,
            quotedMessageAuthorDetailsIsContact: true,
            quotedMessageAlbumMessageImages: [photoA, photoB, photoA],
            quotedMessageAlbumImagesCount: 3,
            bridgeName: "",
            gapFrom: 0,
            gapTo: 0,
            prevMessageIndex: -1,
            prevMessageTimestamp: 0,
            prevMessageSenderId: "",
            prevMessageContentType: Constants.messageContentType.unknownContentType,
            prevMessageDeleted: false,
            nextMessageIndex: -1,
            nextMessageTimestamp: 0,
            mentionsMap: ({})
        })

        function initTestCase() {
            // The first text render populates Qt's font family aliases and
            // logs a one-time performance warning; get it out of the way
            // before the warning-guarded tests run.
            const warmup = createTemporaryObject(fontWarmupComp, root)
            verify(!!warmup)
            wait(100)
        }

        function init() {
            messageStoreMock.messagesById = {
                "orig-img": {
                    isEdited: false,
                    sticker: "",
                    messageImage: photoA,
                    albumImagesCount: 2,
                    albumMessageImages: [photoA, photoB]
                }
            }
        }

        function rebind(view, data) {
            for (const key in data)
                view[key] = data[key]
        }

        function statusMessageOf(view) {
            tryVerify(() => view.status === Loader.Ready && !!view.item)
            const column = view.item
            for (let i = 0; i < column.children.length; ++i) {
                const child = column.children[i]
                if (child.messageDetails !== undefined)
                    return child
            }
            return null
        }

        function test_zeroDataConstructsCleanly() {
            failOnWarning(/.*/)

            const view = createTemporaryObject(bareMessageViewComp, root)
            verify(!!view)
            tryVerify(() => view.status === Loader.Ready)

            const msg = statusMessageOf(view)
            verify(!!msg)
            compare(msg.messageDetails.messageText, "")
            wait(100)
        }

        function test_parkedViewAcquiresMessage() {
            failOnWarning(/.*/)

            const view = createTemporaryObject(bareMessageViewComp, root)
            verify(!!view)
            tryVerify(() => view.status === Loader.Ready)

            view.rootStore = rootStoreMock
            view.messageStore = messageStoreMock
            view.chatContentModule = chatContentModuleMock
            view.joined = true
            rebind(view, messageB)

            const msg = statusMessageOf(view)
            verify(!!msg)
            compare(msg.messageDetails.messageText, "bravo message text")
            compare(msg.messageDetails.sender.displayName, "Bob")
            compare(msg.timestamp, messageB.messageTimestamp)

            const textMessage = findChild(view, "StatusMessage_textMessage")
            verify(!!textMessage)
            tryVerify(() => textMessage.textField.text.indexOf("bravo message text") >= 0)
        }

        function test_rebindLeavesNoResidue() {
            const view = createTemporaryObject(storedMessageViewComp, root)
            verify(!!view)
            rebind(view, messageA)

            const msg = statusMessageOf(view)
            verify(!!msg)

            // A is fully in place: content, reply resolved from the original
            // message, pin, expired outgoing status
            compare(msg.messageDetails.messageText, "alpha message text")
            compare(msg.messageDetails.sender.displayName, "Alice")
            verify(msg.isAReply)
            compare(msg.replyDetails.messageContent, photoA)
            compare(msg.replyDetails.albumCount, 2)
            verify(msg.isPinned)
            tryCompare(msg, "pinnedBy", "Pinner Contact")
            compare(msg.outgoingStatus, StatusMessage.OutgoingStatus.Expired)
            compare(msg.reactionsModel, reactionsA)

            // Retarget to B: every property reassigned, nothing of A remains
            rebind(view, messageB)

            compare(msg.messageDetails.messageText, "bravo message text")
            compare(msg.messageDetails.sender.displayName, "Bob")
            compare(msg.timestamp, messageB.messageTimestamp)
            verify(!msg.isAReply)
            compare(msg.replyDetails.messageContent, "")
            compare(msg.replyDetails.albumCount, 0)
            compare(msg.replyDetails.album.length, 0)
            verify(!msg.isPinned)
            compare(msg.pinnedBy, "")
            compare(msg.outgoingStatus, StatusMessage.OutgoingStatus.Sent)
            compare(msg.reactionsModel, reactionsB)
            verify(!msg.isEdited)

            const textMessage = findChild(view, "StatusMessage_textMessage")
            verify(!!textMessage)
            tryVerify(() => textMessage.textField.text.indexOf("bravo message text") >= 0)
            verify(textMessage.textField.text.indexOf("alpha") < 0)

            // Retarget to C: reply album must come from C's quoted payload,
            // not from A's resolved original
            rebind(view, messageC)

            verify(msg.isAReply)
            compare(msg.replyDetails.albumCount, 3)
            compare(msg.replyDetails.album, [photoA, photoB, photoA])
            compare(msg.replyDetails.messageContent, "")
        }

        function test_variantFlipsKeepTheWarmPath() {
            const view = createTemporaryObject(storedMessageViewComp, root)
            verify(!!view)
            rebind(view, messageB)

            tryVerify(() => view.status === Loader.Ready && !!view.item)
            const warmItem = view.item
            const msg = statusMessageOf(view)

            // all real content types resolve to the same inner component:
            // flipping between them must not rebuild the loaded item
            view.messageContentType = Constants.messageContentType.emojiType
            compare(view.item, warmItem)

            view.messageContentType = Constants.messageContentType.imageType
            view.messageImage = photoB
            compare(view.item, warmItem)
            compare(msg.messageDetails.messageContent, photoB)

            view.messageContentType = Constants.messageContentType.messageType
            view.messageImage = ""
            compare(view.item, warmItem)

            // a displayed message becoming deleted is a component switch...
            view.deleted = true
            view.deletedByContactDisplayName = "Moderator"
            tryVerify(() => view.status === Loader.Ready && view.item !== warmItem)

            // ...and back
            view.deleted = false
            tryVerify(() => view.status === Loader.Ready && !!view.item)
            const restored = statusMessageOf(view)
            verify(!!restored)
            compare(restored.messageDetails.messageText, "bravo message text")
        }
    }
}
