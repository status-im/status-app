import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import utils

import shared.stores as SharedStores
import shared.stores.send as SendStores

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStores

import mainui.adaptors
import mainui.sectionLoaders

import Models
import Storybook

// Exercises the real ChatLoader: loader-owned section chrome with skeleton
// panels, async incubation of the real ChatLayout/ChatView, and the
// skeleton → real panel swap. Refresh recreates the whole loader.
// Note: portrait/landscape follows the storybook WINDOW width (the chrome
// keys off Window.width), so resize the window to see the portrait flow.
SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    // With the extra "profile-exit" positional argument the app quits shortly
    // after the section loads, so an attached qmlprofiler saves its trace on
    // clean exit (storybook's CLI parser rejects unknown --options)
    readonly property bool profileExitMode: Qt.application.arguments.indexOf("profile-exit") >= 0

    Timer {
        id: profilerExitTimer
        interval: 4000
        onTriggered: Qt.exit(0)
    }

    ListModel { id: chatsModel }
    ListModel { id: contactsModel }

    // Each chat gets its own message history model, built lazily when the
    // chat's content module is first requested
    Component {
        id: messagesModelComp
        ListModel {}
    }

    QtObject {
        id: d

        property double loadStartTime: 0
        property var contentModules: ({})
        // unserved rows per chat, consumed by loadMoreMessages
        property var backlogs: ({})
        property int loadMoreCallCount: 0
        readonly property var mockState: ({ preparedChatId: "" })
        property string activeChatId: ""

        // Embedded data-URI images from ModelsData, cycled as contact avatars;
        // every third contact keeps the letter identicon for a realistic mix
        readonly property var avatars: [
            ModelsData.icons.status, ModelsData.icons.superRare,
            ModelsData.icons.coinbase, ModelsData.icons.dragonereum,
            ModelsData.icons.cryptPunks, ModelsData.icons.socks,
            ModelsData.icons.rarible, ModelsData.icons.spotify,
            ModelsData.icons.dribble
        ]

        function avatarFor(i) {
            return i % 3 === 2 ? "" : avatars[i % avatars.length]
        }

        function buildChats(count) {
            chatsModel.clear()
            contactsModel.clear()
            for (let i = 0; i < count; ++i) {
                contactsModel.append({
                    pubKey: "0xpeer-" + i,
                    displayName: "Contact " + i,
                    preferredDisplayName: "Contact " + i,
                    ensName: "",
                    isEnsVerified: false,
                    localNickname: "",
                    alias: "contact alias " + i,
                    icon: avatarFor(i),
                    colorId: i % 10,
                    onlineStatus: i % 2,
                    isContact: true,
                    isVerified: false,
                    isUntrustworthy: false,
                    isBlocked: false,
                    contactRequest: 2,
                    isCurrentUser: false,
                    lastUpdated: 1,
                    lastUpdatedLocally: 1,
                    bio: "",
                    thumbnailImage: avatarFor(i),
                    largeImage: avatarFor(i),
                    isContactRequestReceived: false,
                    isContactRequestSent: false,
                    isRemoved: false,
                    trustStatus: 0
                })
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
                    icon: avatarFor(i),
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

        function fillMessages(model, count, peerIdx, offset) {
            offset = offset || 0
            const now = Date.now()
            // like message_model.nim: logical index 0 is the newest message
            // and history grows towards higher indexes; pages appended via
            // `offset` continue into older history
            for (let j = 0; j < count; ++j) {
                const i = offset + j
                const own = i % 3 === 1
                const ts = now - i * 60000
                model.append({
                    id: "msg-" + peerIdx + "-" + i,
                    prevMsgIndex: i + 1,
                    nextMsgIndex: i - 1,
                    prevMsgTimestamp: ts - 60000,
                    nextMsgTimestamp: ts + 60000,
                    prevMsgSenderId: "",
                    prevMsgContentType: Constants.messageContentType.messageType,
                    prevMsgDeleted: false,
                    timestamp: ts,
                    responseToMessageWithId: "",
                    senderId: own ? "0xdeadbeef" : "0xpeer-" + peerIdx,
                    senderDisplayName: own ? "Me" : "Contact " + peerIdx,
                    senderOptionalName: "",
                    senderIcon: own ? "" : avatarFor(peerIdx),
                    senderIsAdded: true,
                    senderEnsVerified: false,
                    senderTrustStatus: 0,
                    amISender: own,
                    messageText: "Message " + i + " — the quick brown fox jumps over the lazy dog. "
                                 + (i % 5 === 0 ? "A somewhat longer paragraph to vary the bubble heights and make the layout work harder while measuring text. " : ""),
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

        // The message history is filled only when a chat becomes active —
        // mirroring the backend, and keeping the mock-data build cost of
        // inactive chats out of the measured section-load window
        function contentModuleFor(chatId) {
            if (chatId === "")
                return null
            if (!contentModules[chatId]) {
                const idx = chatId.split("-")[1]
                contentModules[chatId] = contentModuleComp.createObject(root, {
                    chatId: chatId,
                    chatName: "Contact " + idx
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
            sectionModuleMock.activeItem = ({ id: id, type: Constants.chatType.oneToOne })
            const module = contentModuleFor(id)
            if (module && !module.messagesModel) {
                module.messagesModel = messagesModelComp.createObject(module)
                // paged like the real backend: first page now, the rest served
                // through loadMoreMessages 20 rows at a time
                const total = ctrlMessages.value
                const firstPage = Math.min(20, total)
                fillMessages(module.messagesModel, firstPage, id.split("-")[1])
                d.backlogs[id] = total - firstPage
            }
            ChatStores.ChatStoresConfig.currentChatContentModule = module
        }
    }

    QtObject {
        id: sectionModuleMock

        property bool chatsLoaded: true
        property var model: chatsModel
        property var activeItem: ({ id: "", type: -1 })
        property bool amIMember: true
        property bool requiresTokenPermissionToJoin: false
        property bool isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin: false
        property int requestToJoinState: 0
        property bool loadingHistoryMessagesInProgress: false

        function isCommunity() { return false }
        function setActiveItem(id) {
            logs.logEvent("setActiveItem: " + id)
            d.setActiveChat(id)
        }
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
            property var messagesModel: null

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
                readonly property var model: contentModule.messagesModel
                readonly property bool loading: false

                signal messageSuccessfullySent()
                signal sendingMessageFailed(string error)
                signal reactionActionFailed()
                signal scrollToMessage(string messageId)

                function getChatId() { return contentModule.chatId }
                function loadMoreMessages() {
                    d.loadMoreCallCount++
                    console.info("loadMoreMessages call #" + d.loadMoreCallCount,
                                 "chat", contentModule.chatId,
                                 "t=" + (Date.now() - d.loadStartTime) + "ms",
                                 "backlog", d.backlogs[contentModule.chatId] || 0)
                    const remaining = d.backlogs[contentModule.chatId] || 0
                    if (remaining <= 0)
                        return
                    const page = Math.min(20, remaining)
                    d.backlogs[contentModule.chatId] = remaining - page
                    const total = ctrlMessages.value
                    Qt.callLater(() => d.fillMessages(contentModule.messagesModel, page,
                                                      contentModule.chatId.split("-")[1],
                                                      total - remaining + 20))
                }
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

    // Non-visual store mocks (typed via the storybook stubs)
    AppStores.RootStore { id: appRootStoreMock }
    AppStores.ContactsStore { id: contactsStoreMock }
    AppStores.AccountSettingsStore {
        id: accountSettingsStoreMock
        showUsersList: ctrlMembers.checked
    }
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
        allContacts: contactsModel
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        // Hidden shared popup loaders the ChatLoader API requires
        Item {
            visible: false
            Loader { id: emojiPopupLoaderMock; active: false }
            Loader { id: stickersPopupLoaderMock; active: false }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.padding
            color: Theme.palette.statusAppLayout.backgroundColor
            border.color: Theme.palette.baseColor2

            Loader {
                id: harness
                anchors.fill: parent
                anchors.margins: 1
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
                    isPortraitMode: (Window.width ?? 0) < ThemeUtils.portraitBreakpoint.width

                    onStatusChanged: {
                        if (status === Loader.Ready) {
                            const ms = Date.now() - d.loadStartTime
                            logs.logEvent("ChatLoader READY in " + ms + " ms")
                            console.info("ChatLoader READY in", ms, "ms")
                            if (root.profileExitMode)
                                profilerExitTimer.start()
                        }
                    }
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 120
        SplitView.preferredHeight: 120
        SplitView.fillWidth: true

        logsView.logText: logs.logText

        RowLayout {
            anchors.fill: parent
            spacing: Theme.bigPadding

            Button {
                objectName: "chatLoaderRefreshButton"
                text: "Refresh"
                onClicked: root.refresh()
            }

            RowLayout {
                Label { text: "Contacts:" }
                SpinBox {
                    id: ctrlChats
                    objectName: "chatLoaderContactsSpinBox"
                    from: 0
                    to: 5000
                    stepSize: 50
                    value: 1000
                    editable: true
                }
            }

            RowLayout {
                Label { text: "Msgs/chat:" }
                SpinBox {
                    id: ctrlMessages
                    objectName: "chatLoaderMessagesSpinBox"
                    from: 0
                    to: 10000
                    stepSize: 100
                    value: 2000
                    editable: true
                }
            }

            Switch {
                id: ctrlMembers
                text: "Members panel"
            }

            Item { Layout.fillWidth: true }
        }
    }

    function refresh() {
        harness.active = false
        ChatStores.ChatStoresConfig.currentChatContentModule = null
        // CommunitySectionMock.install() (community page) writes these too —
        // opening this page after it must not run on the community's mocks
        ChatStores.ChatStoresConfig.sectionDetails = null
        ChatStores.ChatStoresConfig.usersModel = null
        ChatStores.ChatStoresConfig.assetsModel = null
        ChatStores.ChatStoresConfig.collectiblesModel = null
        for (const key in d.contentModules)
            d.contentModules[key].destroy()
        d.contentModules = {}
        d.mockState.preparedChatId = ""
        d.buildChats(ctrlChats.value)
        d.setActiveChat(chatsModel.count > 0 ? "chat-0" : "")
        d.loadStartTime = Date.now()
        harness.active = true
        logs.logEvent("refresh: %1 contacts, %2 messages each".arg(chatsModel.count).arg(ctrlMessages.value))
    }

    Component.onCompleted: {
        ChatStores.ChatStoresConfig.chatSectionModule = sectionModuleMock
        refresh()
    }
}

// category: Panels
