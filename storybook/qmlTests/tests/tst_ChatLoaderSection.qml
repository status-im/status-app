import QtQuick
import QtTest

import utils

import shared.stores as SharedStores
import shared.stores.send as SendStores

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStores

import mainui.adaptors
import mainui.sectionLoaders

// Smoke test for the chrome-inverted ChatLoader: the loader-owned
// StatusSectionLayout shows skeletons, the real ChatLayout/ChatView incubates
// asynchronously against mock stores, and the panels swap in.
Item {
    id: root

    width: 1000
    height: 700

    ListModel { id: chatsModel }
    ListModel { id: messagesModel }

    QtObject {
        id: d

        property var contentModules: ({})
        readonly property var mockState: ({ preparedChatId: "" })
        property string activeChatId: ""

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
                    hasUnreadMessages: false,
                    notificationsCount: 0,
                    highlight: false,
                    icon: "",
                    emoji: "",
                    color: "",
                    colorId: i % 10,
                    categoryOpened: true,
                    hidden: false,
                    usesDefaultName: false,
                    onlineStatus: 1,
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
                const ts = now - (count - i) * 60000
                messagesModel.append({
                    id: "msg-" + i,
                    prevMsgIndex: i - 1,
                    nextMsgIndex: i + 1,
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
                    messageText: "Message " + i,
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
    }

    QtObject {
        id: sectionModuleMock

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

    Loader {
        id: harness
        anchors.fill: parent
        active: false

        sourceComponent: ChatLoader {
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
        }
    }

    TestCase {
        name: "ChatLoaderSection"
        when: windowShown

        function init() {
            ChatStores.ChatStoresConfig.chatSectionModule = sectionModuleMock
            d.buildChats(300)
            d.buildMessages(150)
            d.setActiveChat("chat-0")
        }

        function cleanup() {
            harness.active = false
            ChatStores.ChatStoresConfig.chatSectionModule = null
            ChatStores.ChatStoresConfig.currentChatContentModule = null
            d.contentModules = ({})
                    }

        // Members-panel skeleton behavior is covered by tst_ChatViewMembersSkeleton.

        function findAllIn(item, name, out) {
            if (!item)
                return out
            if (item.objectName === name)
                out.push(item)
            const list = item.children
            for (let i = 0; i < list.length; ++i)
                findAllIn(list[i], name, out)
            return out
        }

        function totalMessageRows(loader) {
            const views = findAllIn(loader, "chatLogView", [])
            let total = 0
            for (let i = 0; i < views.length; ++i)
                total += views[i].contentItem.children.length
            return total
        }

        function activeReadyLogView(loader) {
            const views = findAllIn(loader, "chatLogView", [])
            for (let i = 0; i < views.length; ++i) {
                const lv = views[i]
                if (lv.visible && lv.model && lv.count > 0
                        && lv.contentItem.children.length > 0)
                    return lv
            }
            return null
        }

        // Switching to a chat must cost the same whether its history holds
        // 150 or 3000 messages: only the visible tail is built.
        function test_chatSwitchCostIndependentOfHistorySize() {
            harness.active = true
            const loader = harness.item
            verify(!!loader)
            tryVerify(() => loader.status === Loader.Ready, 60000)
            tryVerify(() => !!activeReadyLogView(loader), 10000)

            function measureSwitch(chatId) {
                const rowsBefore = totalMessageRows(loader)
                const t0 = Date.now()
                d.setActiveChat(chatId)
                const syncMs = Date.now() - t0
                tryVerify(() => {
                    const lv = activeReadyLogView(loader)
                    return !!lv && lv.parent.visible
                }, 120000)
                waitForRendering(loader)
                return { ms: Date.now() - t0, syncMs: syncMs,
                         rows: totalMessageRows(loader) - rowsBefore }
            }

            const small = measureSwitch("chat-1")

            // fresh section with a big history — no residual layout work
            // from the previous lists leaking into the measurement
            harness.active = false
            d.contentModules = ({})
            d.buildMessages(3000)
            harness.active = true
            const loader2 = harness.item
            tryVerify(() => loader2.status === Loader.Ready, 60000)
            d.setActiveChat("chat-0")
            tryVerify(() => !!activeReadyLogView(loader2), 120000)
            waitForRendering(loader2)

            const rowsBefore = totalMessageRows(loader2)
            const t0 = Date.now()
            d.setActiveChat("chat-2")
            const syncMs = Date.now() - t0
            tryVerify(() => {
                const lv = activeReadyLogView(loader2)
                return !!lv && lv.parent.visible
            }, 120000)
            waitForRendering(loader2)
            const large = { ms: Date.now() - t0, syncMs: syncMs,
                            rows: totalMessageRows(loader2) - rowsBefore }

            console.info("chat switch cost: 150 msgs =", small.ms, "ms (sync",
                         small.syncMs, ") /", small.rows,
                         "rows; 3000 msgs =", large.ms, "ms (sync",
                         large.syncMs, ") /", large.rows, "rows")

            verify(small.rows < 100,
                   "switch must build only the visible tail, built "
                   + small.rows + " rows for a 150-message history")
            verify(large.rows < 100,
                   "switch must build only the visible tail, built "
                   + large.rows + " rows for a 3000-message history")
            // generous CI headroom; the point is switch cost must not grow
            // with history size (regressions here are 10-100x, not 2x)
            verify(large.ms < small.ms * 10 + 2000,
                   "switch cost grew with history size: " + small.ms
                   + " ms @150 vs " + large.ms + " ms @3000")
        }

        // Opening a chat must only build delegates for the messages that fit
        // the viewport (plus cache) — never one per historic message.
        function test_messagesListVirtualized() {
            harness.active = true
            const loader = harness.item
            verify(!!loader)
            tryVerify(() => loader.status === Loader.Ready, 60000)

            const lv = findChild(loader, "chatLogView")
            verify(!!lv)
            tryVerify(() => lv.count === 150, 10000)
            waitForRendering(lv)

            const created = lv.contentItem.children.length
            verify(created > 0, "some message rows must be built")
            verify(created < 75,
                   "only viewport+cache rows may be built, got " + created
                   + " of " + lv.count)
        }

        // Loading the section must cost the same whether the chat list holds
        // 300 or 2000 chats: only the visible rows are built.
        function test_sectionLoadCostIndependentOfChatCount() {
            function measureSectionLoad(chatCount) {
                d.buildChats(chatCount)
                d.setActiveChat("chat-0")
                const t0 = Date.now()
                harness.active = true
                const loader = harness.item
                tryVerify(() => loader.status === Loader.Ready, 120000)
                tryVerify(() => !!findChild(loader, "ContactsColumnView_chatList"), 10000)
                waitForRendering(loader)
                const lv = findChild(loader, "ContactsColumnView_chatList").statusChatListItems
                const result = { ms: Date.now() - t0,
                                 rows: lv.contentItem.children.length }
                harness.active = false
                d.contentModules = ({})
                return result
            }

            measureSectionLoad(300) // warmup: first load pays QML compilation

            const small = measureSectionLoad(300)
            const large = measureSectionLoad(2000)
            console.info("section load cost: 300 chats =", small.ms, "ms /",
                         small.rows, "rows; 2000 chats =", large.ms, "ms /",
                         large.rows, "rows")

            verify(large.rows < 100,
                   "only visible chat rows may be built, got " + large.rows)
            // generous CI headroom; a crawl regression is 5-50x, not 2x
            verify(large.ms < small.ms * 3 + 2000,
                   "section load cost grew with chat count: " + small.ms
                   + " ms @300 vs " + large.ms + " ms @2000")
        }

        function test_loadsRealSectionAfterSkeleton() {
            harness.active = true
            const loader = harness.item
            verify(!!loader)

            // While incubating, the loader-owned chrome shows the skeletons
            verify(loader.status !== Loader.Error)

            tryVerify(() => loader.status === Loader.Ready, 60000)
            verify(!!loader.item)

            // The real panels replace the skeletons in the chrome
            tryVerify(() => loader.item.leftPanel !== null, 10000)

            // The real chat list is alive and populated from the mock model
            tryVerify(() => !!findChild(loader, "ContactsColumnView_chatList"), 10000)

            // The list must stay virtualized: only the visible rows (plus
            // cache) may be instantiated, not one delegate per chat
            const chatList = findChild(loader, "ContactsColumnView_chatList")
            const lv = chatList.statusChatListItems
            tryCompare(lv, "count", 300)
            wait(500)
            const created = lv.contentItem.children.length
            console.info("created delegates:", created, "of", lv.count,
                         "| lv height:", lv.height, "contentHeight:", lv.contentHeight)
            verify(created < 60, "expected virtualization, got " + created + " delegates")
        }



        // The message context menu opens for a rendered message (the input
        // simulation variants live in tst_MessageLongTapMenu, where the
        // fixture geometry is faithful)
        function test_messageContextMenuOpens() {
            harness.active = true
            const loader = harness.item
            tryVerify(() => loader.status === Loader.Ready, 60000)
            let bubble = null
            tryVerify(() => {
                bubble = findChild(loader, "StatusMessage_textMessage")
                return !!bubble && bubble.width > 0
            }, 10000)
            // walk up to the MessageView delegate (its root is a Loader with
            // the function)
            let msgView = bubble
            while (msgView && typeof msgView.openMessageContextMenu !== "function")
                msgView = msgView.parent
            verify(!!msgView, "MessageView must be an ancestor of the bubble")
            console.info("guards: joined", msgView.joined,
                         "blocked", msgView.isChatBlocked,
                         "placeholder", msgView.placeholderMessage,
                         "memberPopup", msgView.isViewMemberMessagesePopup,
                         "canReact", msgView.chatContentModule
                                     ? msgView.chatContentModule.chatDetails.canPostReactions : "?",
                         "moving", msgView.chatLogView ? msgView.chatLogView.moving : "?")
            msgView.openMessageContextMenu(Qt.point(10, 10))
            // synchronous check: distinguishes creation failure from an
            // instant close+destroy
            console.info("menu right after open:", !!findChild(msgView, "messageContextMenu_replyTo"))
            wait(500)
            console.info("menu after 500ms:", !!findChild(msgView, "messageContextMenu_replyTo"))
            let menu = null
            for (let i = 0; i < msgView.data.length; ++i) {
                if (msgView.data[i].toString().indexOf("MessageContextMenuView") === 0)
                    menu = msgView.data[i]
            }
            console.info("menu object:", menu ? menu.toString() : "NONE",
                         "opened:", menu ? menu.opened : "-",
                         "visible:", menu ? menu.visible : "-")
            console.info("replyTo via menu:", menu ? !!findChild(menu, "messageContextMenu_replyTo") : "-")
            tryVerify(() => !!findChild(msgView, "messageContextMenu_replyTo"), 3000,
                      "direct invocation must open the message context menu")
        }

    }
}
