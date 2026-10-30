import QtQuick
import QtTest

import utils

import shared.views.chat

import AppLayouts.Chat.stores as ChatStores

/*
 Configuration analysis for MessageView's contact-details entries
 ================================================================

 Per message row, MessageView can hold up to three ContactModelEntry
 instances, each performing a keyed lookup into the contacts model
 (O(contacts) via ModelEntry) plus a ~25-binding ContactDetails object:

 1. senderContactEntry — sender of the row.
    Consumers: openProfileContextMenu() ONLY (click-time). Nothing binds to
    it during creation or display: the header name uses the senderDisplayName
    model role, avatars use senderIcon.
    Side effect at creation: for an unknown sender (contactsModel.hasUser()
    false) it emits populateContactDetailsRequested to prefetch details.
    Contract kept by these tests: the prefetch has happened BY THE TIME the
    profile context menu opens (creation-time vs open-time is an
    implementation detail).

 2. quotedMessageFromContactEntryLoader — author of the quoted (replied-to)
    message. Lazy like the sender's: activated by
    openProfileContextMenu(isReply=true), its only consumer. The reply shows
    the quotedMessageAuthorDetails* model roles. Same prefetch contract as the
    sender's for an unknown author.

 Both lazy entries are deactivated when the row is rebound to another
 message (messageId changes), so a pooled row does not keep resolving the
 contacts of every message it shows.

 3. messagePinnedByContactEntryLoader — who pinned the message. Already
    Loader-gated: active only when messagePinnedBy is set. Consumer: the
    "Pinned by" label.

 A fourth entry (chatContactModelEntry) exists only inside the
 system-message component (contact-request events), which is created only
 for systemMessageMutualEvent* content types — not part of the regular row.

 Row configurations covered:
 - plain text row (no reply, no pin)   → tests 1, 2
 - reply row (quotedMessageFrom set)   → tests 3, 4
 - pinned row (messagePinnedBy set)    → test 5
 - unknown sender (hasUser false)      → test 6
 - unknown quoted author               → test 7
 - row rebound to another message      → test 8
*/
Item {
    id: root

    width: 800
    height: 600

    ListModel {
        id: contactsModel

        property var hasUserCalls: []

        function hasUser(pubKey) {
            hasUserCalls.push(pubKey)
            for (let i = 0; i < count; ++i) {
                if (get(i).pubKey === pubKey)
                    return true
            }
            return false
        }

        Component.onCompleted: {
            append({
                pubKey: "0xsender",
                displayName: "Sender Contact",
                preferredDisplayName: "Sender Contact",
                name: "sender.eth",
                ensName: "",
                isEnsVerified: false,
                localNickname: "Nick",
                alias: "sender alias",
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
                compressedPubKey: "zQsender"
            })
        }
    }

    ChatStores.RootStore {
        id: rootStoreMock

        property var contactsModel: contactsModel
        property var populateRequests: []

        function populateContactDetailsRequested(pubKey) {
            populateRequests.push(pubKey)
        }
    }

    ChatStores.MessageStore { id: messageStoreMock }

    QtObject {
        id: chatContentModuleMock

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property int type: Constants.chatType.oneToOne
            readonly property bool canPostReactions: true
        }
    }

    Component {
        id: messageViewComp

        MessageView {
            width: 600

            rootStore: rootStoreMock
            messageStore: messageStoreMock
            chatContentModule: chatContentModuleMock

            messageId: "msg-1"
            senderId: "0xsender"
            senderDisplayName: "Sender Contact"
            unparsedText: "hello world"
            messageTimestamp: Date.now()
            messageContentType: Constants.messageContentType.messageType
            amISender: false
        }
    }

    TestCase {
        name: "MessageViewSenderEntry"
        when: windowShown

        function init() {
            contactsModel.hasUserCalls = []
            rootStoreMock.populateRequests = []
        }

        // INTENT (perf): building a plain row must not touch the contacts
        // model — the sender entry is needed only when the profile context
        // menu opens
        function test_plainRowDoesNotLookupContacts() {
            const view = createTemporaryObject(messageViewComp, root)
            verify(!!view)
            tryVerify(() => view.status === Loader.Ready)
            wait(50)

            compare(contactsModel.hasUserCalls.length, 0,
                    "row creation must not query the contacts model, got: "
                    + JSON.stringify(contactsModel.hasUserCalls))
        }

        // Opening the profile context menu resolves the sender through the
        // contacts model and opens with contact data
        function test_profileContextMenuUsesContactDetails() {
            const view = createTemporaryObject(messageViewComp, root)
            tryVerify(() => view.status === Loader.Ready)

            const opened = view.openProfileContextMenu(10, 10)
            verify(opened !== false, "menu must open for a regular sender")
            verify(contactsModel.hasUserCalls.length > 0,
                   "menu open must resolve the sender via the contacts model")

            // the opened menu is created as a child of the view
            const menu = findChild(root, "profileContextMenu")
            if (menu)
                menu.close()
        }

        // INTENT (perf): building a reply row must not touch the contacts
        // model either — the quoted author's entry is needed only when its
        // profile context menu opens
        function test_replyRowDoesNotLookupContacts() {
            const reply = createTemporaryObject(messageViewComp, root, {
                quotedMessageFrom: "0xsender",
                responseToMessageWithId: "msg-0"
            })
            tryVerify(() => reply.status === Loader.Ready)
            wait(50)

            compare(reply.quotedMessageFromContactEntryLoader.active, false)
            compare(contactsModel.hasUserCalls.length, 0,
                    "reply row creation must not query the contacts model, got: "
                    + JSON.stringify(contactsModel.hasUserCalls))
        }

        // Opening the quoted author's profile context menu resolves the
        // author through the contacts model
        function test_quotedAuthorEntryOnMenuOpen() {
            const reply = createTemporaryObject(messageViewComp, root, {
                quotedMessageFrom: "0xsender",
                responseToMessageWithId: "msg-0"
            })
            tryVerify(() => reply.status === Loader.Ready)

            const opened = reply.openProfileContextMenu(10, 10, true)
            verify(opened !== false, "menu must open for a quoted author")
            compare(reply.quotedMessageFromContactEntryLoader.active, true)
            verify(!!reply.quotedMessageFromContactEntryLoader.item)
            compare(reply.quotedMessageFromContactEntryLoader.item.contactDetails.displayName,
                    "Sender Contact")

            const menu = findChild(root, "profileContextMenu")
            if (menu)
                menu.close()
        }

        // Pinned rows activate the pinned-by entry; plain rows do not
        function test_pinnedByEntryGating() {
            const plain = createTemporaryObject(messageViewComp, root)
            tryVerify(() => plain.status === Loader.Ready)
            compare(plain.messagePinnedByContactEntryLoader.active, false)

            const pinned = createTemporaryObject(messageViewComp, root, {
                pinnedMessage: true,
                messagePinnedBy: "0xsender"
            })
            tryVerify(() => pinned.status === Loader.Ready)
            compare(pinned.messagePinnedByContactEntryLoader.active, true)
            tryVerify(() => !!pinned.messagePinnedByContactEntryLoader.item)
            compare(pinned.messagePinnedByContactEntryLoader.item.contactDetails.localNickname,
                    "Nick")
        }

        // Unknown sender: the details prefetch must have been requested by
        // the time the profile context menu opens (contract independent of
        // whether it fires at creation or at open)
        function test_unknownSenderPrefetchByMenuOpen() {
            const view = createTemporaryObject(messageViewComp, root, {
                senderId: "0xunknown",
                senderDisplayName: "Stranger"
            })
            tryVerify(() => view.status === Loader.Ready)

            view.openProfileContextMenu(10, 10)
            verify(rootStoreMock.populateRequests.indexOf("0xunknown") >= 0,
                   "unknown sender details must be requested by menu-open time")

            const menu = findChild(root, "profileContextMenu")
            if (menu)
                menu.close()
        }

        // Unknown quoted author: same contract as for the sender
        function test_unknownQuotedAuthorPrefetchByMenuOpen() {
            const reply = createTemporaryObject(messageViewComp, root, {
                quotedMessageFrom: "0xunknownauthor",
                responseToMessageWithId: "msg-0"
            })
            tryVerify(() => reply.status === Loader.Ready)
            compare(rootStoreMock.populateRequests.indexOf("0xunknownauthor"), -1,
                    "nothing must be requested before the menu opens")

            reply.openProfileContextMenu(10, 10, true)
            verify(rootStoreMock.populateRequests.indexOf("0xunknownauthor") >= 0,
                   "unknown quoted author details must be requested by menu-open time")

            const menu = findChild(root, "profileContextMenu")
            if (menu)
                menu.close()
        }

        // A pooled row rebound to another message drops the entries the
        // previous message's menus activated
        function test_rebindDeactivatesContactEntries() {
            const reply = createTemporaryObject(messageViewComp, root, {
                quotedMessageFrom: "0xsender",
                responseToMessageWithId: "msg-0"
            })
            tryVerify(() => reply.status === Loader.Ready)

            reply.openProfileContextMenu(10, 10, false)
            reply.openProfileContextMenu(10, 10, true)
            compare(reply.senderContactEntry.active, true)
            compare(reply.quotedMessageFromContactEntryLoader.active, true)

            reply.messageId = "msg-2"

            compare(reply.senderContactEntry.active, false)
            compare(reply.quotedMessageFromContactEntryLoader.active, false)

            const menu = findChild(root, "profileContextMenu")
            if (menu)
                menu.close()
        }
    }
}
