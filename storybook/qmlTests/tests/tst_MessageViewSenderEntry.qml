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
    message. Already Loader-gated: active only when quotedMessageFrom is set.
    Consumers: openProfileContextMenu(isReply=true).

 3. messagePinnedByContactEntryLoader — who pinned the message. Already
    Loader-gated: active only when messagePinnedBy is set. Consumer: the
    "Pinned by" label.

 A fourth entry (chatContactModelEntry) exists only inside the
 system-message component (contact-request events), which is created only
 for systemMessageMutualEvent* content types — not part of the regular row.

 Row configurations covered:
 - plain text row (no reply, no pin)   → tests 1, 2
 - reply row (quotedMessageFrom set)   → test 3
 - pinned row (messagePinnedBy set)    → test 4
 - unknown sender (hasUser false)      → test 5
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
            messageText: "hello world"
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

        // Reply rows activate the quoted-author entry; plain rows do not
        function test_quotedAuthorEntryGating() {
            const plain = createTemporaryObject(messageViewComp, root)
            tryVerify(() => plain.status === Loader.Ready)
            compare(plain.quotedMessageFromContactEntryLoader.active, false)

            const reply = createTemporaryObject(messageViewComp, root, {
                quotedMessageFrom: "0xsender",
                responseToMessageWithId: "msg-0"
            })
            tryVerify(() => reply.status === Loader.Ready)
            compare(reply.quotedMessageFromContactEntryLoader.active, true)
            tryVerify(() => !!reply.quotedMessageFromContactEntryLoader.item)
            compare(reply.quotedMessageFromContactEntryLoader.item.contactDetails.displayName,
                    "Sender Contact")
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
    }
}
