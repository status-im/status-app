import QtQuick
import QtTest

import StatusQ

import utils

import shared.stores as SharedStores
import shared.stores.send as SendStores

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStores

import mainui.adaptors
import mainui.sectionLoaders

import StorybookMocks

// Load bench for the chat section surface (issues/0023).
//
// Same shape as tst_WalletSectionLoadBench: the load staircase from
// `ChatLoader.active = true`, a 1ms stall probe through the window, a settle
// point observed rather than waited out, two phases per run with the warm one
// as the headline.
//
// It exists for one reason: every number the incubation cadence was chosen on
// came from the wallet, and the controller paces every asynchronous Loader in
// the app. This is the second, non-wallet surface that check needs.
//
// Content stop line: the first realised row in the active chat's `chatLogView`.
// The nested loaders reaching Ready does not establish it here any more than it
// did on the wallet - the message list fills on the layout pass that follows.
Item {
    id: root

    // Fixed geometry: delegate counts are gated and a list fills as many
    // delegates as its height allows.
    width: 1440
    height: 900

    // Heavy profile: a chat list long enough to virtualise and a history long
    // enough that the message list is not trivially short.
    readonly property int chatCount: 1000
    readonly property int messageCount: 2000

    ListModel { id: chatsModel }
    ListModel { id: messagesModel }

    WalletLoadBenchProbe { id: probe }

    QtObject {
        id: d

        property var contentModules: ({})
        readonly property var mockState: ({ preparedChatId: "" })
        property string activeChatId: ""

        property var section: null
        property var leftPanelLoader: null
        property var centerPanelLoader: null
        property var leftPanelLoaders: []
        property var centerPanelLoaders: []

        property int objectsTotal: -1
        property int chatDelegates: -1
        property int messageDelegates: -1

        property var stallTimeline: []
        property var stampList: []
        property int stallsOver8: -1
        property real firstMessageRowMs: -1
        property int objectsSettled: -1
        property int messageDelegatesSettled: -1

        function buildChats(count) {
            chatsModel.clear()
            for (let i = 0; i < count; ++i) {
                chatsModel.append({
                    itemId: "chat-" + i,
                    categoryId: "",
                    name: "Contact " + i,
                    type: Constants.chatType.oneToOne,
                    muted: false,
                    active: false,
                    loaderActive: false,
                    blocked: false,
                    hasUnreadMessages: i % 7 === 0,
                    notificationsCount: i % 7 === 0 ? (i % 3) + 1 : 0,
                    highlight: false,
                    icon: "",
                    emoji: "",
                    color: "",
                    colorId: i % 10,
                    categoryOpened: true,
                    hidden: false,
                    usesDefaultName: false,
                    onlineStatus: i % 2,
                    requiresPermissions: false,
                    locked: false,
                    isCategory: false,
                    position: i,
                    categoryPosition: -1
                })
            }
        }

        function buildMessages(count) {
            messagesModel.clear()
            const now = Date.now()
            for (let i = 0; i < count; ++i) {
                const own = i % 3 === 1
                const ts = now - i * 60000
                messagesModel.append({
                    id: "msg-" + i,
                    prevMsgIndex: i + 1,
                    nextMsgIndex: i - 1,
                    prevMsgTimestamp: ts - 60000,
                    nextMsgTimestamp: ts + 60000,
                    prevMsgSenderId: "",
                    prevMsgContentType: Constants.messageContentType.messageType,
                    prevMsgDeleted: false,
                    timestamp: ts,
                    responseToMessageWithId: "",
                    senderId: own ? "0xdeadbeef" : "0xpeer",
                    senderDisplayName: own ? "Me" : "Contact 0",
                    senderOptionalName: "",
                    senderIcon: "",
                    senderIsAdded: true,
                    senderEnsVerified: false,
                    senderTrustStatus: 0,
                    amISender: own,
                    messageText: "Message " + i + " - the quick brown fox jumps over the lazy dog. "
                                 + (i % 5 === 0 ? "A somewhat longer paragraph to vary the bubble "
                                                + "heights and make the layout work harder. " : ""),
                    unparsedText: "Message " + i,
                    messageImage: "",
                    messageAttachments: "",
                    contentType: Constants.messageContentType.messageType,
                    sticker: "",
                    stickerPack: -1,
                    outgoingStatus: own ? "sent" : "",
                    resendError: "",
                    mentioned: false,
                    quotedMessageText: "",
                    quotedMessageParsedText: "",
                    quotedMessageFrom: "",
                    quotedMessageAuthorDisplayName: "",
                    quotedMessageAuthorName: "",
                    quotedMessageAuthorThumbnailImage: "",
                    quotedMessageAuthorEnsVerified: false,
                    quotedMessageAuthorIsContact: false,
                    quotedMessageContentType: Constants.messageContentType.messageType,
                    quotedMessageDeleted: false,
                    quotedMessageAlbumImagesCount: 0,
                    quotedMessageAlbumMessageImages: "",
                    linkPreviewModel: [],
                    links: "",
                    paymentRequestModel: [],
                    transactionParameters: [],
                    pinned: false,
                    pinnedBy: "",
                    reactions: [],
                    editMode: false,
                    isEdited: false,
                    deleted: false,
                    deletedBy: "",
                    deletedByContactDisplayName: "",
                    deletedByContactIcon: "",
                    gapFrom: 0,
                    gapTo: 0,
                    communityId: "",
                    compressedKey: "",
                    bridgeName: "",
                    albumMessageImages: "",
                    albumImagesCount: 0,
                    usesDefaultName: false
                })
            }
        }

        function contentModuleFor(chatId) {
            if (chatId === "")
                return null
            if (!contentModules[chatId]) {
                contentModules[chatId] = contentModuleComp.createObject(root, {
                    chatId: chatId,
                    chatName: "Contact " + chatId.split("-")[1]
                })
            }
            return contentModules[chatId]
        }

        function setActiveChat(id) {
            for (let i = 0; i < chatsModel.count; ++i) {
                const isActive = chatsModel.get(i).itemId === id
                chatsModel.setProperty(i, "active", isActive)
                if (isActive)
                    chatsModel.setProperty(i, "loaderActive", true)
            }
            d.activeChatId = id
            sectionModuleMock.activeItem = ({ id: id })
            ChatStores.ChatStoresConfig.currentChatContentModule = contentModuleFor(id)
        }

        function asyncLoadersIn(subtreeRoot) {
            if (!subtreeRoot)
                return []
            return probe.findAllByTypePrefix(subtreeRoot, "QQuickLoader")
                        .filter(loader => loader.asynchronous)
        }

        // The section's panels are reached through the chrome's slots: like the
        // wallet section they keep their QObject parent while their visual
        // parent moves to the chrome.
        function watchNestedLoaders(section) {
            d.section = section
            const layout = section.item
            d.leftPanelLoaders = d.asyncLoadersIn(layout.leftPanel)
            d.centerPanelLoaders = d.asyncLoadersIn(layout.centerPanel)
            d.leftPanelLoader = d.leftPanelLoaders.length > 0 ? d.leftPanelLoaders[0] : null
            d.centerPanelLoader = d.centerPanelLoaders.length > 0 ? d.centerPanelLoaders[0] : null
            d.stampContentWhenReady()
        }

        function stampContentWhenReady() {
            if (probe.hasStamp("t_content"))
                return
            if (!d.section)
                return
            // Both panels exist as soon as the section loads; an asynchronous
            // one is an empty Loader until it reports Ready.
            for (const loader of d.leftPanelLoaders.concat(d.centerPanelLoaders)) {
                if (loader.status !== Loader.Ready)
                    return
            }
            probe.stamp("t_content")
            d.takeInstantiationCounts()
        }

        function takeInstantiationCounts() {
            d.objectsTotal = probe.countObjects(d.section)
            d.chatDelegates = probe.countByTypePrefix(d.section, "StatusChatListItem")
            d.messageDelegates = d.messageRows()
        }

        // Rows realised by the active chat's log view. `chatLogView` is the
        // ListView ChatMessagesView owns; its contentItem children are the
        // realised delegates.
        function messageRows() {
            if (!d.section)
                return 0
            const views = probe.findAllByObjectNamePrefix(d.section, "chatLogView")
            let total = 0
            for (const view of views)
                total += view.contentItem.children.length
            return total
        }

        function resetPhase() {
            d.section = null
            d.leftPanelLoader = null
            d.centerPanelLoader = null
            d.leftPanelLoaders = []
            d.centerPanelLoaders = []
            d.objectsTotal = -1
            d.chatDelegates = -1
            d.messageDelegates = -1
            d.firstMessageRowMs = -1
            d.stallsOver8 = -1
            d.objectsSettled = -1
            d.messageDelegatesSettled = -1
            d.stallTimeline = []
            d.stampList = []
        }

        function snapshot(phase) {
            return ({
                phase: phase,
                skeletonMs: probe.stampMs("t_skeleton"),
                readyMs: probe.stampMs("t_ready"),
                contentMs: probe.stampMs("t_content"),
                firstMessageRowMs: d.firstMessageRowMs,
                stalls: probe.stallCount,
                stallsOver8: d.stallsOver8,
                maxStallMs: probe.maxStallMs,
                probeTicks: probe.stallTickCount,
                objectsTotal: d.objectsTotal,
                chatDelegates: d.chatDelegates,
                messageDelegates: d.messageDelegates,
                objectsSettled: d.objectsSettled,
                messageDelegatesSettled: d.messageDelegatesSettled,
                stallTimeline: d.stallTimeline,
                stampTimeline: d.stampList
            })
        }

        // 1ms slices to the first realised message row, then drain until the
        // object count holds still over two 50ms samples. Both stop conditions
        // are observed, never waited out by a fixed delay.
        function settle(timeoutMs) {
            const deadline = probe.elapsedMs + timeoutMs

            while (d.messageRows() === 0 && probe.elapsedMs < deadline)
                probe.waitForStamp("never-stamped", 1)
            d.firstMessageRowMs = probe.elapsedMs

            let previous = -1
            let current = probe.countObjects(d.section)
            while (current !== previous && probe.elapsedMs < deadline) {
                previous = current
                probe.waitForStamp("never-stamped", 50)
                current = probe.countObjects(d.section)
            }

            probe.end()
            d.stallTimeline = probe.stalls()
            d.stallsOver8 = d.stallTimeline.filter(stall => stall.gapMs > 8).length
            d.stampList = probe.stampTimeline()
            d.objectsSettled = current
            d.messageDelegatesSettled = d.messageRows()
        }
    }

    QtObject {
        id: sectionModuleMock

        property bool chatsLoaded: true
        property var model: chatsModel
        property var activeItem: ({ id: "" })
        property bool amIMember: true
        property bool requiresTokenPermissionToJoin: false
        property bool isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin: false
        property int requestToJoinState: 0
        property bool loadingHistoryMessagesInProgress: false

        function isCommunity() { return false }
        function setActiveItem(id) { d.setActiveChat(id) }
        function prepareChatContentModuleForChatId(chatId) { d.mockState.preparedChatId = chatId }
        function getChatContentModule() { return d.contentModuleFor(d.mockState.preparedChatId) }
        function getItemAsJson(id) { return "{}" }
        function muteChat(chatId, interval) {}
        function unmuteChat(chatId) {}
        function markAllMessagesRead(chatId) {}
        function clearChatHistory(chatId) {}
        function leaveChat(chatId) {}
        function updateGroupChatDetails() {}
        function createOneToOneChat(ensName, pubKey, nickname) {}
    }

    Component {
        id: contentModuleComp

        QtObject {
            id: contentModule

            property string chatId
            property string chatName

            readonly property var chatDetails: QtObject {
                readonly property string id: contentModule.chatId
                readonly property string name: contentModule.chatName
                readonly property int type: Constants.chatType.oneToOne
                readonly property bool active: contentModule.chatId === d.activeChatId
                readonly property bool muted: false
                readonly property bool hasUnreadMessages: false
                readonly property bool highlight: false
                readonly property string emoji: ""
                readonly property bool canView: true
                readonly property bool canPost: true
                readonly property bool canPostReactions: true
                readonly property bool missingEncryptionKey: false
                readonly property bool isUsersListAvailable: true
                readonly property string color: "#4360DF"
                readonly property string description: ""
            }

            readonly property var messagesModule: QtObject {
                readonly property var model: messagesModel
                readonly property bool loading: false

                signal messageSuccessfullySent()
                signal sendingMessageFailed(string error)
                signal reactionActionFailed()
                signal scrollToMessage(string messageId)

                function getChatId() { return contentModule.chatId }
                function loadMoreMessages() {}
                function updateKeepUnread(flag) {}
            }

            readonly property var inputAreaModule: QtObject {
                readonly property var preservedProperties: ({ text: "" })
                function clearLinkPreviewCache() {}
            }

            readonly property ListModel pinnedMessagesModel: ListModel {}

            function markAllMessagesRead() {}
            function markMessageRead(id) {}
            function getMyChatId() { return contentModule.chatId }
            function amIChatAdmin() { return false }
        }
    }

    AppStores.RootStore { id: appRootStoreMock }
    AppStores.ContactsStore { id: contactsStoreMock }
    AppStores.AccountSettingsStore { id: accountSettingsStoreMock }
    AppStores.FeatureFlagsStore { id: featureFlagsStoreMock }
    SharedStores.RootStore { id: sharedRootStoreMock }
    SharedStores.CurrenciesStore { id: currenciesStoreMock }
    SharedStores.CommunityTokensStore { id: communityTokensStoreMock }
    SharedStores.NetworkConnectionStore { id: networkConnectionStoreMock }
    SharedStores.NetworksStore { id: networksStoreMock }
    SendStores.TransactionStore { id: transactionStoreMock }
    WalletStores.TokensStore {
        id: tokensStoreMock
        networksStore: networksStoreMock
    }
    WalletStores.WalletAssetsStore { id: walletAssetsStoreMock }
    ProfileStores.AdvancedStore { id: advancedStoreMock }
    ChatStores.CreateChatPropertiesStore { id: createChatPropertiesStoreMock }
    ContactsModelAdaptor {
        id: contactsAdaptorMock
        allContacts: ListModel {}
    }

    Item {
        visible: false
        Loader { id: emojiPopupLoaderMock; active: false }
        Loader { id: stickersPopupLoaderMock; active: false }
    }

    Connections {
        target: d.leftPanelLoader
        function onStatusChanged() { d.stampContentWhenReady() }
    }

    Connections {
        target: d.centerPanelLoader
        function onStatusChanged() { d.stampContentWhenReady() }
    }

    // Synchronous on purpose: activating it is the start of the measurement
    // window, so nothing of the section may be built before that assignment.
    Loader {
        id: harness

        anchors.fill: parent
        active: false

        sourceComponent: ChatLoader {
            id: chatLoader

            active: true

            rootStore: appRootStoreMock
            contactsStore: contactsStoreMock
            accountSettingsStore: accountSettingsStoreMock
            featureFlagsStore: featureFlagsStoreMock
            sharedRootStore: sharedRootStoreMock
            currencyStore: currenciesStoreMock
            communityTokensStore: communityTokensStoreMock
            networkConnectionStore: networkConnectionStoreMock
            networksStore: networksStoreMock
            transactionStore: transactionStoreMock
            tokensStore: tokensStoreMock
            walletAssetsStore: walletAssetsStoreMock
            advancedStore: advancedStoreMock
            createChatPropertiesStore: createChatPropertiesStoreMock
            contactsAdaptor: contactsAdaptorMock
            popupHandler: null
            emojiPopupLoader: emojiPopupLoaderMock
            stickersPopupLoader: stickersPopupLoaderMock
            createChatViewOpened: false
            isPortraitMode: false

            onStatusChanged: {
                if (status !== Loader.Ready)
                    return
                probe.stamp("t_ready")
                // `harness.item` is not assigned yet when the section loads
                // synchronously, so the section is handed over by id.
                d.watchNestedLoaders(chatLoader)
            }
        }
    }

    TestCase {
        name: "ChatSectionLoadBench"
        when: windowShown

        readonly property string tsvPath:
            probe.sourceDir + "/benches/baselines/chat-section-load.tsv"

        readonly property var tsvHeader: [
            "utc_time", "profile", "phase",
            "t_skeleton_ms", "t_ready_ms", "t_content_ms", "t_first_message_row_ms",
            "stalls_over_4ms", "stalls_over_8ms", "max_stall_ms", "probe_ticks",
            "objects_total", "chat_delegates", "message_delegates",
            "objects_settled", "message_delegates_settled",
            "gentle_bite_ms", "gentle_interval_ms"
        ]

        function initTestCase() {
            ChatStores.ChatStoresConfig.chatSectionModule = sectionModuleMock
            d.buildChats(root.chatCount)
            d.buildMessages(root.messageCount)
            d.setActiveChat("chat-0")
        }

        function cleanupTestCase() {
            harness.active = false
            ChatStores.ChatStoresConfig.chatSectionModule = null
            ChatStores.ChatStoresConfig.currentChatContentModule = null
            d.contentModules = ({})
        }

        function test_chatSectionLoadStaircase() {
            const cold = loadPhase("cold")
            teardownSection()
            const warm = loadPhase("warm")

            printStaircase(cold, warm)
            printTimeline(cold)
            printTimeline(warm)
            recordRow(cold)
            recordRow(warm)

            // No count gate yet: this bench exists to A/B a controller
            // constant, and its own baseline is recorded before anything is
            // ratcheted against it. What is asserted is that both phases built
            // the same section - the invariant the wallet bench gates on.
            verify(warm.objectsSettled === cold.objectsSettled,
                   "objects_settled differs between phases: cold %1, warm %2 - the section must "
                   .arg(cold.objectsSettled).arg(warm.objectsSettled)
                   + "build the same objects whether or not the process has seen it before")
            verify(warm.messageDelegatesSettled === cold.messageDelegatesSettled,
                   "message_delegates_settled differs between phases: cold %1, warm %2"
                   .arg(cold.messageDelegatesSettled).arg(warm.messageDelegatesSettled))
        }

        function loadPhase(phase) {
            d.resetPhase()

            probe.begin()
            harness.active = true
            probe.stamp("t_skeleton")

            const skeleton = probe.findByObjectNamePrefix(harness.item, "centerPanelSkeleton")
            verify(!!skeleton,
                   "%1: time-to-skeleton, no centre-panel skeleton in the section chrome"
                   .arg(phase))

            verify(probe.waitForStamp("t_ready", 120000),
                   "%1: the chat section never reached Loader.Ready".arg(phase))
            verify(probe.waitForStamp("t_content", 120000),
                   "%1: time-to-content, the section's panels never all reached Loader.Ready"
                   .arg(phase))

            d.settle(120000)
            verify(d.firstMessageRowMs < 120000,
                   "%1: the message list never realised a row after time-to-content".arg(phase))

            return d.snapshot(phase)
        }

        // Destroys the section but not the engine: the QML types and the store
        // singletons stay, which is what makes the next load the warm one.
        function teardownSection() {
            harness.active = false
            probe.waitForStamp("never-stamped", 200)
        }

        function printStaircase(cold, warm) {
            const incubation = IncubationHints.stats()
            const lines = [
                "",
                "chat section load staircase (%1 chats / %2 messages, HOST ms)"
                .arg(root.chatCount).arg(root.messageCount),
                "  gentle incubation cadence: %1ms bite every %2ms (%3% duty)"
                .arg(incubation.gentleBudgetMs).arg(incubation.gentleIntervalMs)
                .arg(Math.round(100 * incubation.gentleBudgetMs / incubation.gentleIntervalMs)),
                "  metric                        warm        cold  role",
                row("t_skeleton_ms", warm.skeletonMs, cold.skeletonMs, "recorded"),
                row("t_ready_ms", warm.readyMs, cold.readyMs, "recorded"),
                row("t_content_ms", warm.contentMs, cold.contentMs, "recorded"),
                row("t_first_message_row_ms", warm.firstMessageRowMs, cold.firstMessageRowMs,
                    "recorded (HEADLINE: warm)"),
                row("stalls_over_4ms", warm.stalls, cold.stalls, "recorded"),
                row("stalls_over_8ms", warm.stallsOver8, cold.stallsOver8, "recorded"),
                row("max_stall_ms", warm.maxStallMs, cold.maxStallMs, "recorded"),
                row("probe_ticks", warm.probeTicks, cold.probeTicks, "recorded"),
                row("objects_total", warm.objectsTotal, cold.objectsTotal, "recorded"),
                row("chat_delegates", warm.chatDelegates, cold.chatDelegates, "recorded"),
                row("message_delegates", warm.messageDelegates, cold.messageDelegates, "recorded"),
                row("objects_settled", warm.objectsSettled, cold.objectsSettled,
                    "asserted equal across phases"),
                row("message_delegates_settled", warm.messageDelegatesSettled,
                    cold.messageDelegatesSettled, "asserted equal across phases"),
                ""
            ]
            for (const line of lines)
                console.info(line)
        }

        function printTimeline(phase) {
            console.info("")
            console.info("%1 phase - stamp timeline (host ms)".arg(phase.phase))
            for (const stamp of phase.stampTimeline)
                console.info("    %1  %2".arg(probe.formatMs(stamp.ms).padStart(10))
                             .arg(stamp.name))
            console.info("%1 phase - GUI-thread blocks over %2ms (host ms)"
                         .arg(phase.phase).arg(probe.stallThresholdMs))
            for (const stall of phase.stallTimeline)
                console.info("    %1 -> %2   %3".arg(probe.formatMs(stall.startMs).padStart(10))
                             .arg(probe.formatMs(stall.endMs).padStart(10))
                             .arg(probe.formatMs(stall.gapMs).padStart(8)))
            console.info("")
        }

        function row(metric, warmValue, coldValue, role) {
            return "  %1%2%3  %4".arg(metric.padEnd(24)).arg(pad(warmValue))
                                 .arg(pad(coldValue)).arg(role)
        }

        function pad(value) {
            const text = typeof value === "number" && !Number.isInteger(value)
                       ? probe.formatMs(value) : String(value)
            return text.padStart(10)
        }

        function recordRow(phase) {
            const incubation = IncubationHints.stats()
            const row = [
                probe.utcTimestamp(),
                "chat-%1c-%2m".arg(root.chatCount).arg(root.messageCount),
                phase.phase,
                probe.formatMs(phase.skeletonMs),
                probe.formatMs(phase.readyMs),
                probe.formatMs(phase.contentMs),
                probe.formatMs(phase.firstMessageRowMs),
                String(phase.stalls), String(phase.stallsOver8),
                probe.formatMs(phase.maxStallMs), String(phase.probeTicks),
                String(phase.objectsTotal), String(phase.chatDelegates),
                String(phase.messageDelegates),
                String(phase.objectsSettled), String(phase.messageDelegatesSettled),
                String(incubation.gentleBudgetMs), String(incubation.gentleIntervalMs)
            ]
            verify(probe.appendTsvRow(tsvPath, tsvHeader, row),
                   "could not append the %1 bench row to %2".arg(phase.phase).arg(tsvPath))
        }
    }
}
