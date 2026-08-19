import QtQuick
import QtTest

import utils

import shared.views.chat

import StatusQ 0.1
import StatusQ.Core.Theme
import Storybook.Benchmark 1.0

import AppLayouts.Chat.stores as ChatStores

/*
 Rebind benchmark gate (issue 0004): measures retargeting a pool-style
 MessageView across model rows via RowBinder (per-rebind wall time) against
 cold creation of the same rows. The verdict on pooling fat MessageView
 hangs on these numbers — keep the fixture rows representative.

 sync   = the RowBinder.bind() call: bulk property writes + eager binding
          re-evaluation on the warm item
 settled = sync + one event-loop flush + item polish (text layout); async
          image decode is NOT included (it happens off the GUI thread)
*/
Item {
    id: root

    width: 800
    height: 600

    ListModel {
        id: contactsModel

        function hasUser(pubKey) {
            return false
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
            readonly property int type: Constants.chatType.communityChat
            readonly property bool canPostReactions: true
            readonly property bool canPost: true
            readonly property bool canView: true
        }
    }

    ListModel {
        id: rowsModel
    }

    BenchTimer {
        id: perfTimer
    }

    RowBinder {
        id: rebinder
    }

    RowBinder {
        id: creationBinder
    }

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
        name: "MessageViewRebindBenchmark"
        when: windowShown

        readonly property string photoA: Assets.png("chat/chat@2x")
        readonly property string photoB: Assets.png("chat/request_payment_banner")

        readonly property int rowsPerCase: 12
        readonly property int rebindsPerCase: 60
        readonly property int creationsPerCase: 25

        // filled by appendCaseRows() in initTestCase
        property var caseRows: ({})

        readonly property double baseTimestamp: 1755600000000

        function makeReactions(rowIndex, count) {
            const emojis = ["1f600", "1f602", "2764", "1f44d", "1f389",
                            "1fae3", "1f604", "1f575-fe0f-200d-2642-fe0f"]
            const reactions = []
            for (let i = 0; i < count; ++i) {
                reactions.push({
                    emoji: emojis[(rowIndex + i) % emojis.length],
                    didIReactWithThisEmoji: (i % 3) === 0,
                    numberOfReactions: 1 + ((rowIndex + i) % 7),
                    jsonArrayOfUsersReactedWithThisEmoji: "[\"Bob\", \"John\"]"
                })
            }
            return reactions
        }

        function makeRow(i, overrides) {
            const senders = [
                { id: "0xalice", name: "Alice", key: "zQalice" },
                { id: "0xbob", name: "Bob", key: "zQbob" },
                { id: "0xcarol", name: "Carol", key: "zQcarol" },
                { id: "0xdave", name: "Dave", key: "zQdave" }
            ]
            const sender = senders[i % senders.length]

            const row = {
                messageId: "msg-" + i,
                communityId: "",
                responseToMessageWithId: "",
                senderId: sender.id,
                senderDisplayName: sender.name,
                usesDefaultName: false,
                senderOptionalName: "",
                senderIsEnsVerified: false,
                senderIcon: "",
                senderIsAdded: true,
                senderTrustStatus: 0,
                compressedKey: sender.key,
                amISender: false,
                messageText: "message text " + i,
                unparsedText: "message text " + i,
                messageImage: "",
                albumCount: 0,
                messageTimestamp: baseTimestamp + i * 60000,
                messageOutgoingStatus: "",
                resendError: "",
                messageContentType: Constants.messageContentType.messageType,
                pinnedMessage: false,
                messagePinnedBy: "",
                reactionsModel: [],
                sticker: "",
                stickerPack: -1,
                editModeOn: false,
                isEdited: false,
                deleted: false,
                deletedBy: "",
                deletedByContactDisplayName: "",
                deletedByContactIcon: "",
                links: "",
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
                nextMessageTimestamp: 0
            }

            for (const key in overrides)
                row[key] = overrides[key]
            return row
        }

        function appendCaseRows(label, overridesFor) {
            const first = rowsModel.count
            for (let i = 0; i < rowsPerCase; ++i) {
                const globalIndex = rowsModel.count
                rowsModel.append(makeRow(globalIndex, overridesFor(globalIndex, i)))
            }
            const indices = []
            for (let i = first; i < first + rowsPerCase; ++i)
                indices.push(i)
            caseRows[label] = indices
        }

        function longParagraph(i) {
            let text = "Paragraph seed " + i + ". "
            for (let s = 0; s < 30; ++s) {
                text += "The quick brown fox jumps over the lazy dog while "
                      + "sentence " + ((i + s) % 17) + " keeps the layout "
                      + "engine honest with realistically long prose. "
            }
            return text
        }

        function initTestCase() {
            // first rich-text render logs a one-time font warning; flush it
            const warmup = createTemporaryObject(fontWarmupComp, root)
            verify(!!warmup)
            wait(100)

            messageStoreMock.messagesById = {
                "orig-img": {
                    isEdited: false,
                    sticker: "",
                    messageImage: photoA,
                    albumImagesCount: 2,
                    albumMessageImages: [photoA, photoB]
                }
            }

            // row 0 is the neutral "from" row every non-text case rebinds
            // away from
            rowsModel.append(makeRow(0, {}))
            caseRows = {}

            appendCaseRows("text-to-text", (g, i) => ({}))
            appendCaseRows("text-to-image", (g, i) => ({
                messageContentType: Constants.messageContentType.imageType,
                messageImage: (i % 2 === 0) ? photoA : photoB
            }))
            appendCaseRows("reply-with-album", (g, i) => ({
                responseToMessageWithId: "orig-img",
                quotedMessageText: "quoted " + g,
                quotedMessageUnparsedText: "quoted " + g,
                quotedMessageFrom: "0xalice",
                quotedMessageContentType: Constants.messageContentType.imageType,
                quotedMessageAuthorDetailsDisplayName: "Alice",
                quotedMessageAuthorDetailsIsContact: true
            }))
            appendCaseRows("reactions-heavy", (g, i) => ({
                reactionsModel: makeReactions(g, 8)
            }))
            appendCaseRows("long-paragraph", (g, i) => ({
                messageText: longParagraph(g),
                unparsedText: longParagraph(g)
            }))
        }

        function median(values) {
            const sorted = values.slice().sort((a, b) => a - b)
            return sorted[Math.floor(sorted.length / 2)]
        }

        function worst(values) {
            return Math.max(...values)
        }

        function fmt(ms) {
            return ms.toFixed(2)
        }

        // Builds the pool item the way the pool will: bare, no data, then
        // dressed with stores once and parked on the neutral row.
        function buildPoolView() {
            const view = createTemporaryObject(bareMessageViewComp, root)
            verify(!!view)
            tryVerify(() => view.status === Loader.Ready && !!view.item)

            view.rootStore = rootStoreMock
            view.messageStore = messageStoreMock
            view.chatContentModule = chatContentModuleMock
            view.joined = true

            rebinder.target = view
            rebinder.bind(rowsModel, 0)
            verify(rebinder.bound)
            settle(view)
            return view
        }

        function settle(view) {
            wait(0)
            if (view.item)
                waitForItemPolished(view.item)
        }

        function measureRebinds(label) {
            const indices = caseRows[label]
            verify(indices !== undefined && indices.length > 0)

            const view = buildPoolView()
            const interleaveBase = label !== "text-to-text"

            // warm the case's inner path once before measuring
            rebinder.bind(rowsModel, indices[0])
            settle(view)
            rebinder.bind(rowsModel, 0)
            settle(view)

            const sync = []
            const settled = []
            let prevRow = 0
            for (let i = 0; i < rebindsPerCase; ++i) {
                let target = indices[i % indices.length]
                if (target === prevRow)
                    target = indices[(i + 1) % indices.length]

                perfTimer.start()
                rebinder.bind(rowsModel, target)
                const syncMs = perfTimer.elapsedMs()
                settle(view)
                const settledMs = perfTimer.elapsedMs()

                sync.push(syncMs)
                settled.push(settledMs)
                prevRow = target

                if (interleaveBase) {
                    rebinder.bind(rowsModel, 0)
                    settle(view)
                    prevRow = 0
                }
            }

            // sanity: the last measured rebind actually landed
            compare(view.messageId, rowsModel.get(prevRow).messageId)

            console.info("BENCH rebind case=" + label
                         + " n=" + sync.length
                         + " sync_median_ms=" + fmt(median(sync))
                         + " sync_worst_ms=" + fmt(worst(sync))
                         + " settled_median_ms=" + fmt(median(settled))
                         + " settled_worst_ms=" + fmt(worst(settled)))

            rebinder.detach()
            rebinder.target = null
            view.destroy()
            wait(0)
        }

        function measureCreations(label) {
            const indices = caseRows[label]
            verify(indices !== undefined && indices.length > 0)

            const sync = []
            const ready = []
            for (let i = 0; i < creationsPerCase; ++i) {
                const row = indices[i % indices.length]

                perfTimer.start()
                const view = createTemporaryObject(storedMessageViewComp, root)
                verify(!!view)
                creationBinder.target = view
                creationBinder.bind(rowsModel, row)
                const syncMs = perfTimer.elapsedMs()
                tryVerify(() => view.status === Loader.Ready && !!view.item)
                if (view.item)
                    waitForItemPolished(view.item)
                sync.push(syncMs)
                ready.push(perfTimer.elapsedMs())

                creationBinder.detach()
                creationBinder.target = null
                view.destroy()
                wait(0)
            }

            console.info("BENCH create case=" + label
                         + " n=" + ready.length
                         + " sync_median_ms=" + fmt(median(sync))
                         + " sync_worst_ms=" + fmt(worst(sync))
                         + " ready_median_ms=" + fmt(median(ready))
                         + " ready_worst_ms=" + fmt(worst(ready)))
        }

        function benchmark_data() {
            return [
                { tag: "text-to-text" },
                { tag: "text-to-image" },
                { tag: "reply-with-album" },
                { tag: "reactions-heavy" },
                { tag: "long-paragraph" }
            ]
        }

        function test_rebindVsCreation_data() {
            return benchmark_data()
        }

        function test_rebindVsCreation(data) {
            measureRebinds(data.tag)
            measureCreations(data.tag)
        }
    }
}
