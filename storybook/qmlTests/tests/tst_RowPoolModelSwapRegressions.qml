import QtQuick
import QtTest

import StatusQ 0.1
import utils

import shared.views.chat

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

/*
 Regressions from the Android real-profile debugging session: chats
 with history show the scrollable skeleton forever. Recreates the two
 conditions the committed tests lack: (A) the messages model attaches AFTER
 the view exists (loading flips false / rows arrive async), (B) constant
 foreign incubation pressure competing with the pool.
*/
Item {
    id: root

    width: 480
    height: 800

    ChatStores.RootStore { id: rootStoreMock }

    ListModel { id: messagesModel }

    QtObject {
        id: contentModuleMock

        property int markAllMessagesReadCalls: 0
        function markAllMessagesRead() { markAllMessagesReadCalls++ }

        readonly property var chatDetails: QtObject {
            readonly property string id: "chat-1"
            readonly property int type: Constants.chatType.oneToOne
            readonly property bool active: true
            readonly property bool highlight: false
            property bool hasUnreadMessages: false
            readonly property bool canPost: true
            readonly property bool canView: true
            readonly property bool canPostReactions: true
            readonly property string emoji: ""
        }

        readonly property var messagesModule: QtObject {
            readonly property var model: messagesModel
            property bool loading: true
            property bool keepUnread: false

            signal messageSuccessfullySent()
            signal sendingMessageFailed(string error)
            signal reactionActionFailed()
            signal scrollToMessage(string messageId)

            function getChatId() { return "chat-1" }
            function loadMoreMessages() {}
            function updateKeepUnread(flag) {}
        }

        function getMyChatId() { return "chat-1" }
        function amIChatAdmin() { return false }
    }

    Component {
        id: poolComp

        DelegatePool {
            DelegatePoolKind {
                objectName: "messageKind"
                kind: "message"
                target: 0

                delegate: Component {
                    MessageView {}
                }
            }
        }
    }

    // Mirrors the committed section harness: one shell + ONE shared messages
    // view reparented into its slot.
    Component {
        id: sectionComp

        Item {
            id: harness

            width: 480
            height: 800

            property DelegatePool rowPool: null
            readonly property alias sharedView: sharedView

            ChatContentView {
                id: shellA
                anchors.fill: parent
                visible: true
                rootStore: rootStoreMock
                chatContentModule: contentModuleMock
                chatId: "chat-1"
                chatType: Constants.chatType.oneToOne
            }

            Item {
                id: parkingHolder
                anchors.fill: parent
                visible: false
            }

            ChatMessagesView {
                id: sharedView
                parent: shellA.messagesSlot
                anchors.fill: parent

                rowPool: harness.rowPool
                rootStore: rootStoreMock
                messageStore: shellA.messageStore
                chatContentModule: shellA.chatContentModule
                chatId: shellA.chatId
                isOneToOne: true
                usersModel: ListModel {}
                joined: true
            }
        }
    }

    // (B) foreign incubation pressure: async Loaders churning continuously
    // through the engine's incubation controller.
    Component {
        id: pressureComp

        Item {
            id: pressureRoot

            property int cycle: 0

            Timer {
                interval: 30; running: true; repeat: true
                onTriggered: pressureRoot.cycle++
            }

            Repeater {
                model: 4
                delegate: Loader {
                    required property int index
                    asynchronous: true
                    sourceComponent: (pressureRoot.cycle + index) % 2 === 0 ? pressureLeafA
                                                                            : pressureLeafB
                }
            }
        }
    }

    Component { id: pressureLeafA; Item { Repeater { model: 30; Item {} } } }
    Component { id: pressureLeafB; Item { Repeater { model: 30; Rectangle { width: 1; height: 1 } } } }

    // Second, independent section (its own module/model/shell/shared view)
    // sharing the SAME pool — the cross-section path from the device trail.
    ListModel { id: messagesModelB }

    QtObject {
        id: contentModuleMockB

        function markAllMessagesRead() {}

        readonly property var chatDetails: QtObject {
            readonly property string id: "chan-B"
            readonly property int type: Constants.chatType.communityChat
            readonly property bool active: true
            readonly property bool highlight: false
            property bool hasUnreadMessages: false
            readonly property bool canPost: true
            readonly property bool canView: true
            readonly property bool canPostReactions: true
            readonly property string emoji: ""
        }

        readonly property var messagesModule: QtObject {
            readonly property var model: messagesModelB
            property bool loading: true
            property bool keepUnread: false

            signal messageSuccessfullySent()
            signal sendingMessageFailed(string error)
            signal reactionActionFailed()
            signal scrollToMessage(string messageId)

            function getChatId() { return "chan-B" }
            function loadMoreMessages() {}
            function updateKeepUnread(flag) {}
        }

        function getMyChatId() { return "chan-B" }
        function amIChatAdmin() { return false }
    }

    Component {
        id: sectionBComp

        Item {
            id: harnessB

            width: 480
            height: 800

            property DelegatePool rowPool: null
            readonly property alias sharedView: sharedViewB

            ChatContentView {
                id: shellB
                anchors.fill: parent
                visible: true
                rootStore: rootStoreMock
                chatContentModule: contentModuleMockB
                chatId: "chan-B"
                chatType: Constants.chatType.communityChat
            }

            Item {
                id: parkingHolderB
                anchors.fill: parent
                visible: false
            }

            ChatMessagesView {
                id: sharedViewB
                parent: shellB.messagesSlot
                anchors.fill: parent

                rowPool: harnessB.rowPool
                rootStore: rootStoreMock
                messageStore: shellB.messageStore
                chatContentModule: shellB.chatContentModule
                chatId: shellB.chatId
                usersModel: ListModel {}
                joined: true
            }
        }
    }

    TestCase {
        name: "RowPoolRealProfileProbe"
        when: windowShown

        function init() {
            contentModuleMock.messagesModule.loading = true
            contentModuleMockB.messagesModule.loading = true
            messagesModel.clear()
            messagesModelB.clear()
        }

        function messageRoles(id, i, ts) {
            return {
                id: id, communityId: "", compressedKey: "zQ3peer",
                prevMsgIndex: i + 1, nextMsgIndex: i - 1,
                prevMsgTimestamp: ts - 60000, nextMsgTimestamp: ts + 60000,
                prevMsgSenderId: "", prevMsgContentType: 1, prevMsgDeleted: false,
                timestamp: ts, responseToMessageWithId: "",
                senderId: "0xpeer", senderDisplayName: "Peer", senderOptionalName: "",
                senderIcon: "", senderIsAdded: true, senderEnsVerified: false,
                senderTrustStatus: 0, amISender: false, usesDefaultName: true,
                messageText: "Message " + i, unparsedText: "Message " + i,
                messageImage: "", messageAttachments: "",
                albumImagesCount: 0, albumMessageImages: "",
                contentType: 1, sticker: "", stickerPack: -1,
                editMode: false, isEdited: false, outgoingStatus: "", resendError: "",
                mentioned: false, gapFrom: 0, gapTo: 0,
                quotedMessageText: "", quotedMessageParsedText: "", quotedMessageFrom: "",
                quotedMessageContentType: 1, quotedMessageDeleted: false,
                quotedMessageAuthorName: "", quotedMessageAuthorDisplayName: "",
                quotedMessageAuthorThumbnailImage: "", quotedMessageAuthorEnsVerified: false,
                quotedMessageAuthorIsContact: false,
                quotedMessageAlbumImagesCount: 0, quotedMessageAlbumMessageImages: "",
                reactions: "", pinned: false, pinnedBy: "",
                deleted: false, deletedBy: "",
                deletedByContactDisplayName: "", deletedByContactIcon: "",
                bridgeName: "", links: "", transactionParameters: ""
            }
        }

        function fillModel(n) {
            for (let i = 0; i < n; ++i)
                messagesModel.append(messageRoles("msg-" + i, i, Date.now() - i * 60000))
        }

        function visibleRowCount(listView) {
            let n = 0
            for (let k = 0; k < listView.count; ++k) {
                const item = listView.itemAtRow(k)
                if (item && item.visible && item.height > 0)
                    ++n
            }
            return n
        }

        // (A) real-profile sequencing: view exists first with loading=true;
        // then history lands and loading flips. Symptom: skeleton forever.
        function test_asyncModelAttachReveals() {
            const pool = createTemporaryObject(poolComp, root, { backgroundIntervalMs: 40 })
            verify(!!pool)
            const section = createTemporaryObject(sectionComp, root, { rowPool: pool })
            verify(!!section)

            const listView = findChild(section, "chatLogView")
            verify(!!listView)

            // history arrives late, then loading clears — backend order
            fillModel(200)
            contentModuleMock.messagesModule.loading = false

            tryVerify(() => visibleRowCount(listView) > 0, 20000,
                      "rows must reveal after the async model attach")
        }

        function fillModelB(n) {
            for (let i = 0; i < n; ++i)
                messagesModelB.append(messageRoles("b-" + i, i, Date.now() - i * 60000))
        }

        // Device trail, chat B: model attaches small (2 rows), then a
        // loading round-trip replaces it with more history. On device the
        // view ended holding the WHOLE pool (acquired == target) with only
        // 14 rows, starving everything after.
        function test_doubleResetGrowingHistoryKeepsAccountsSane() {
            const pool = createTemporaryObject(poolComp, root, { backgroundIntervalMs: 40 })
            verify(!!pool)
            const kind = findChild(pool, "messageKind")
            verify(!!kind)
            const section = createTemporaryObject(sectionComp, root, { rowPool: pool })
            verify(!!section)
            const listView = findChild(section, "chatLogView")
            const internal = findChild(section, "chatMessagesViewInternal")
            verify(!!listView && !!internal)

            fillModel(2)
            contentModuleMock.messagesModule.loading = false
            tryVerify(() => visibleRowCount(listView) > 0, 20000)

            // backend refetch round-trip: source detaches, history grows
            contentModuleMock.messagesModule.loading = true
            messagesModel.clear()
            fillModel(14)
            contentModuleMock.messagesModule.loading = false

            tryVerify(() => visibleRowCount(listView) >= 14, 20000,
                      "all 14 rows must reveal, showed "
                      + visibleRowCount(listView))
            tryVerify(() => internal.acquiredCount <= listView.count, 5000,
                      "view must not hold more items than rows: acquired "
                      + internal.acquiredCount + " rows " + listView.count)
        }

        // Device trail, the community switch: a SECOND view (other section)
        // sharing the same pool becomes visible while the first un-dresses.
        // On device the first view kept the whole pool (headroom stayed 0)
        // and the second stalled into an empty reveal — skeleton forever.
        function test_sectionFlipHandsThePoolToTheOtherView() {
            const pool = createTemporaryObject(poolComp, root, { backgroundIntervalMs: 40 })
            verify(!!pool)
            const kind = findChild(pool, "messageKind")
            verify(!!kind)

            const sectionA = createTemporaryObject(sectionComp, root, { rowPool: pool })
            verify(!!sectionA)
            const listViewA = findChild(sectionA, "chatLogView")
            const internalA = findChild(sectionA, "chatMessagesViewInternal")

            fillModel(22)
            contentModuleMock.messagesModule.loading = false
            tryVerify(() => visibleRowCount(listViewA) > 0, 20000)

            const sectionB = createTemporaryObject(sectionBComp, root,
                                                   { rowPool: pool, visible: false })
            verify(!!sectionB)
            const listViewB = findChild(sectionB, "chatLogView")
            const internalB = findChild(sectionB, "chatMessagesViewInternal")
            fillModelB(22)
            contentModuleMockB.messagesModule.loading = false

            // the section flip
            sectionA.visible = false
            sectionB.visible = true

            tryVerify(() => internalA.acquiredCount === 0, 10000,
                      "the un-dressed view must hand everything back, holds "
                      + internalA.acquiredCount)
            tryVerify(() => visibleRowCount(listViewB) > 0, 20000,
                      "the other section's view must dress and reveal")

            // and back
            sectionB.visible = false
            sectionA.visible = true
            tryVerify(() => internalB.acquiredCount === 0, 10000,
                      "B must hand everything back, holds " + internalB.acquiredCount)
            tryVerify(() => visibleRowCount(listViewA) > 0, 20000,
                      "A must re-dress on return")
        }

        // (A)+(B): same, under continuous foreign incubation churn.
        function test_asyncModelAttachRevealsUnderIncubationPressure() {
            const pressure = createTemporaryObject(pressureComp, root)
            verify(!!pressure)

            const pool = createTemporaryObject(poolComp, root, { backgroundIntervalMs: 40 })
            verify(!!pool)
            const section = createTemporaryObject(sectionComp, root, { rowPool: pool })
            verify(!!section)

            const listView = findChild(section, "chatLogView")
            verify(!!listView)

            fillModel(200)
            contentModuleMock.messagesModule.loading = false

            tryVerify(() => visibleRowCount(listView) > 0, 20000,
                      "rows must reveal under incubation pressure")
        }
    }
}
