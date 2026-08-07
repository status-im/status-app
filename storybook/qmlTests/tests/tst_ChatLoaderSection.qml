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
            }

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
    WalletStores.TokensStore { id: tokensStoreMock }
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
