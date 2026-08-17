import QtQuick

import utils

import AppLayouts.Chat.stores as ChatStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.stores.Messaging.Community as CommunityStores

/*!
    Fully configurable mock community backing the CommunityChatLoader, used
    by the storybook page (benchmarks) and built for reuse by qml tests
    (regression) added later in this PR stack.

    Configure the properties, then call install(); it wires the stub store
    hooks (ChatStoresConfig + MessagingStoresConfig) and builds:
      - the chats model (categories, public and private channels)
      - the community and private-channel members models
      - the token-permissions model (with belongsToChat, like the nim model)
      - the section item model and the community section module mock
    Call uninstall() in cleanup — the hooks are global singletons.
*/
QtObject {
    id: root

    // Community identity
    property string communityId: "communityMock"
    property string name: "Mock Community"
    property string description: "A community for storybook and tests"
    property string introMessage: "Welcome to the mock community"
    property string color: "#4360DF"
    property string image: ""

    // My membership / join state
    property bool joined: true
    property int memberRole: Constants.memberRole.none
    property bool amIBanned: false
    property int requestToJoinState: Constants.RequestToJoinState.None
    property bool requiresTokenPermissionToJoin: false
    property bool isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin: false
    property bool spectated: false
    property int access: Constants.communityChatOnRequestAccess

    // Scale
    property int membersCount: 50
    property int categoriesCount: 2
    property int channelsPerCategory: 5
    property int uncategorizedChannelsCount: 2
    // the last N channels of every category are token-gated
    property int privateChannelsPerCategory: 1
    property int privateChannelMembersCount: 10
    property int messagesPerChannel: 150

    // What my (mocked) permissions grant on the private channels
    property bool canViewPrivateChannels: true
    property bool canPostInPrivateChannels: true

    // Token permissions
    property int becomeMemberPermissionsCount: 1
    property int viewOnlyPermissionsCount: 1     // scoped to the private channels
    property int viewAndPostPermissionsCount: 1  // scoped to the private channels
    property bool permissionsArePrivate: false
    property bool tokenCriteriaMet: true
    property bool allTokenRequirementsMet: true

    // Permission-check machinery state
    property bool permissionsCheckOngoing: false
    property int communityMemberReevaluationStatus: 0
    property bool allChannelsAreHiddenBecauseNotPermitted: false

    property string activeChatId: ""

    // Built models
    // Wallet models resolving permission holdings to symbols/icons; the
    // generated holdings cycle over the assets below
    readonly property AssetsModel assetsModel: AssetsModel {}
    readonly property CollectiblesModel collectiblesModel: CollectiblesModel {}
    readonly property ListModel chatsModel: ListModel {}
    readonly property ListModel membersModel: ListModel {}
    readonly property ListModel privateChannelMembersModel: ListModel {}
    readonly property ListModel permissionsModel: ListModel {
        // permissionId -> [chatIds]; absent/empty = community-wide
        property var channelMap: ({})

        function belongsToChat(permissionId, chatId) {
            const channels = channelMap[permissionId]
            if (!channels || channels.length === 0)
                return true
            return channels.indexOf(chatId) !== -1
        }
    }

    // Row of mainModule.sectionsModel for this community (all roles of
    // src/app/modules/shared_models/section_model.nim)
    readonly property QtObject sectionItemModel: QtObject {
        readonly property string id: root.communityId
        readonly property int sectionType: Constants.appSection.community
        readonly property string name: root.name
        readonly property int memberRole: root.memberRole
        readonly property bool isControlNode: false
        readonly property string description: root.description
        readonly property string introMessage: root.introMessage
        readonly property string outroMessage: ""
        readonly property string image: root.image
        readonly property string bannerImageData: ""
        readonly property string icon: ""
        readonly property string color: root.color
        readonly property var tags: []
        readonly property bool hasNotification: false
        readonly property int notificationsCount: 0
        readonly property bool active: true
        readonly property bool enabled: true
        readonly property bool joined: root.joined
        readonly property bool spectated: root.spectated
        readonly property bool isMember: root.joined
        // the production role is named isMember; ChatLayout reads amIMember —
        // expose both so either spelling behaves
        readonly property bool amIMember: root.joined
        readonly property bool canJoin: !root.joined
        readonly property bool canManageUsers: root.memberRole === Constants.memberRole.owner
                                               || root.memberRole === Constants.memberRole.admin
        readonly property bool canRequestAccess: !root.joined
        readonly property int access: root.access
        readonly property bool ensOnly: false
        readonly property bool muted: false
        // counters follow the built model (membersCount + the current user)
        // so UI counts never disagree with the members list
        readonly property int allMembers: root.membersModel.count
        readonly property int joinedMembersCount: root.membersModel.count
        readonly property bool historyArchiveSupportEnabled: false
        readonly property bool pinMessageAllMembersEnabled: false
        readonly property bool encrypted: root.requiresTokenPermissionToJoin
        readonly property var communityTokens: []
        readonly property bool amIBanned: root.amIBanned
        readonly property bool isPendingOwnershipRequest: false
        readonly property int activeMembersCount: root.membersModel.count
        readonly property bool membersLoaded: true
        readonly property bool tokensLoading: false
    }

    // Mock of the nim chatCommunitySectionModule
    readonly property QtObject sectionModule: QtObject {
        readonly property var model: root.chatsModel
        property var activeItem: ({ id: "", type: -1 })
        readonly property bool amIMember: root.joined
        readonly property bool requiresTokenPermissionToJoin: root.requiresTokenPermissionToJoin
        readonly property bool isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin: root.isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin
        readonly property int requestToJoinState: root.requestToJoinState
        readonly property bool loadingHistoryMessagesInProgress: false
        readonly property bool chatsLoaded: true
        readonly property var membersModel: root.membersModel
        readonly property var contactRequestsModel: null
        readonly property string emoji: ""

        signal openNoPermissionsToJoinPopup(string communityName, string chatName, string communityId, string chatId)
        signal permissionSavedSuccessfully()

        function isCommunity() { return true }
        function setActiveItem(id) { root.setActiveChat(id) }
        function prepareChatContentModuleForChatId(chatId) { d.preparedChatId = chatId }
        function getChatContentModule() { return d.contentModuleFor(d.preparedChatId) }
        function getItemAsJson(id) { return JSON.stringify(d.chatInfo[id] ?? {}) }
        function getMySectionId() { return root.communityId }

        function muteChat(chatId, interval) {}
        function unmuteChat(chatId) {}
        function muteCategory(categoryId, interval) {}
        function unmuteCategory(categoryId) {}
        function markAllMessagesRead(chatId) {}
        function clearChatHistory(chatId) {}
        function leaveChat(chatId) {}
        function leaveCommunity() {}
        function updateGroupChatDetails() {}
        function createOneToOneChat(ensName, pubKey, nickname) {}
        function removeMemberFromGroupChat(chatId, pubKey) {}
        function createCommunityChannel(name, description, emoji, color, categoryId, viewersCanPostReactions) {}
        function editCommunityChannel(chatId, name, description, emoji, color, categoryId, viewersCanPostReactions) {}
        function removeCommunityChat(chatId) {}
        function createCommunityCategory(name, channels) {}
        function editCommunityCategory(categoryId, name, channels) {}
        function deleteCommunityCategory(categoryId) {}
        function prepareEditCategoryModel(categoryId) {}
        function reorderCommunityCategories(categoryId, position) {}
        // captured for tests
        property var lastReorder: null
        function reorderCommunityChat(categoryId, chatId, position) {
            lastReorder = ({ categoryId: categoryId, chatId: chatId, to: position })
            d.applyChatReorder(categoryId, chatId, position)
        }
        function toggleCollapsedCommunityCategory(categoryId, collapsed) { root.setCategoryOpened(categoryId, !collapsed) }
        function removeUserFromCommunity(pubKey) {}
        function banUserFromCommunity(pubKey, deleteAllMessages) {}
        function unbanUserFromCommunity(pubKey) {}
        function loadCommunityMemberMessages(pubKey) {}
        function collectCommunityMetricsMessagesCount(intervals) {}
        function collectCommunityMetricsMessagesTimestamps(intervals) {}
    }

    // Stub store instances handed to the loader-created CommunityRootStore
    readonly property CommunityStores.CommunityAccessStore accessStore: CommunityStores.CommunityAccessStore {
        communityId: root.communityId
        joined: root.joined
        allChannelsAreHiddenBecauseNotPermitted: root.allChannelsAreHiddenBecauseNotPermitted
        communityMemberReevaluationStatus: root.communityMemberReevaluationStatus
        spectatedPermissionsModel: root.permissionsModel
        communityPermissionsCheckOngoing: root.permissionsCheckOngoing
        chatPermissionsCheckOngoing: root.permissionsCheckOngoing
        isMyCommunityRequestPending: root.requestToJoinState !== Constants.RequestToJoinState.None
    }

    readonly property CommunityStores.PermissionsStore permissionsStore: CommunityStores.PermissionsStore {
        activeSectionId: root.communityId
        activeChannelId: root.activeChatId
        allTokenRequirementsMet: root.allTokenRequirementsMet
        permissionsModel: root.permissionsModel
    }

    readonly property Component communityRootStoreComponent: Component {
        CommunityStores.CommunityRootStore {
            communityId: root.communityId
            communityAccessStore: root.accessStore
            communityPermissionsStore: root.permissionsStore
        }
    }

    readonly property Component messagesModelComponent: Component {
        ListModel {}
    }

    readonly property Component contentModuleComponent: Component {
        QtObject {
            id: contentModule

            property string chatId
            property var info
            property var messagesModel: null

            readonly property var chatDetails: QtObject {
                readonly property string id: contentModule.chatId
                readonly property string name: contentModule.info.name
                readonly property int type: Constants.chatType.communityChat
                readonly property bool belongsToCommunity: true
                readonly property bool requiresPermissions: contentModule.info.requiresPermissions
                readonly property bool active: contentModule.chatId === root.activeChatId
                readonly property bool muted: false
                readonly property bool hasUnreadMessages: false
                readonly property bool highlight: false
                readonly property string emoji: ""
                readonly property bool canView: contentModule.info.canView
                readonly property bool canPost: contentModule.info.canPost
                readonly property bool canPostReactions: true
                readonly property bool missingEncryptionKey: false
                readonly property bool isUsersListAvailable: true
                readonly property bool blocked: false
                readonly property string icon: ""
                readonly property int notificationCount: 0
                readonly property string color: root.color
                readonly property string description: contentModule.info.description
            }

            readonly property ListModel pinnedMessagesModel: ListModel {}

            readonly property var messagesModule: QtObject {
                readonly property var model: contentModule.messagesModel
                readonly property bool loading: false

                signal messageSuccessfullySent()
                signal sendingMessageFailed(string error)
                signal reactionActionFailed()
                signal scrollToMessage(string messageId)

                function getChatId() { return contentModule.chatId }
                function loadMoreMessages() {}
                function updateKeepUnread(flag) {}
            }

            readonly property var usersModule: QtObject {
                readonly property var model: contentModule.info.requiresPermissions
                                             ? root.privateChannelMembersModel
                                             : root.membersModel
            }

            readonly property var inputAreaModule: QtObject {
                readonly property var preservedProperties: ({ text: "" })
                readonly property bool sendingInProgress: false
                readonly property var linkPreviewModel: null
                readonly property var paymentRequestModel: null
                readonly property bool askToEnableLinkPreview: false

                function clearLinkPreviewCache() {}
            }

            function markAllMessagesRead() {}
            function markMessageRead(id) {}
            function getMyChatId() { return contentModule.chatId }
            function amIChatAdmin() {
                return root.memberRole === Constants.memberRole.owner
                        || root.memberRole === Constants.memberRole.admin
            }
        }
    }

    readonly property QtObject d: QtObject {
        id: d

        property string preparedChatId: ""
        property var contentModules: ({})
        // chatId -> { name, description, requiresPermissions, canView, canPost }
        property var chatInfo: ({})

        function appendChatRow(itemId, chatName, isCategory, categoryId, position,
                               categoryPosition, isPrivate) {
            root.chatsModel.append({
                itemId: itemId,
                name: chatName,
                usesDefaultName: false,
                memberRole: root.memberRole,
                icon: "",
                color: root.color,
                colorId: position >= 0 ? position % 10 : 0,
                emoji: "",
                description: isCategory ? "" : "Description of " + chatName,
                type: isCategory ? Constants.chatType.category : Constants.chatType.communityChat,
                lastMessageTimestamp: 0,
                lastMessageText: "",
                hasUnreadMessages: false,
                notificationsCount: 0,
                muted: false,
                blocked: false,
                active: false,
                selected: false,
                position: position,
                categoryId: categoryId,
                hideIfPermissionsNotMet: false,
                categoryPosition: categoryPosition,
                highlight: false,
                categoryOpened: true,
                trustStatus: 0,
                onlineStatus: 1,
                isCategory: isCategory,
                loaderActive: false,
                locked: isPrivate && !root.canViewPrivateChannels,
                requiresPermissions: isPrivate,
                canPost: !isPrivate || root.canPostInPrivateChannels,
                canView: !isPrivate || root.canViewPrivateChannels,
                canPostReactions: true,
                viewersCanPostReactions: true,
                shouldBeHiddenBecausePermissionsAreNotMet: false,
                missingEncryptionKey: false,
                permissionsCheckOngoing: false
            })
            if (!isCategory) {
                d.chatInfo[itemId] = {
                    name: chatName,
                    description: "Description of " + chatName,
                    requiresPermissions: isPrivate,
                    canView: !isPrivate || root.canViewPrivateChannels,
                    canPost: !isPrivate || root.canPostInPrivateChannels
                }
            }
        }

        // Mirrors the backend: move the chat row into `categoryId` at
        // `position`, then renumber positions per category from row order.
        function applyChatReorder(categoryId, chatId, position) {
            let from = -1
            for (let i = 0; i < root.chatsModel.count; ++i) {
                if (root.chatsModel.get(i).itemId === chatId) {
                    from = i
                    break
                }
            }
            if (from === -1)
                return

            // target model index: position-th channel row of the category
            let to = -1
            let channelIndex = 0
            for (let i = 0; i < root.chatsModel.count; ++i) {
                const row = root.chatsModel.get(i)
                if (row.isCategory || row.categoryId !== categoryId)
                    continue
                if (channelIndex === position) {
                    to = i
                    break
                }
                ++channelIndex
            }
            if (to === -1 || to === from)
                return

            root.chatsModel.move(from, to, 1)
            root.chatsModel.setProperty(to, "categoryId", categoryId)

            const positions = ({})
            for (let i = 0; i < root.chatsModel.count; ++i) {
                const row = root.chatsModel.get(i)
                if (row.isCategory)
                    continue
                const next = (positions[row.categoryId] || 0)
                positions[row.categoryId] = next + 1
                if (row.position !== next)
                    root.chatsModel.setProperty(i, "position", next)
            }
        }

        function buildChats() {
            root.chatsModel.clear()
            d.chatInfo = ({})
            for (let u = 0; u < root.uncategorizedChannelsCount; ++u)
                appendChatRow("channel-u-" + u, "channel-" + u, false, "", u, -1, false)
            for (let c = 0; c < root.categoriesCount; ++c) {
                const categoryId = "category-" + c
                appendChatRow(categoryId, "Category " + c, true, categoryId, -1, c, false)
                for (let i = 0; i < root.channelsPerCategory; ++i) {
                    const isPrivate = i >= root.channelsPerCategory - root.privateChannelsPerCategory
                    appendChatRow("channel-" + c + "-" + i,
                                  (isPrivate ? "private-" : "") + "channel-" + c + "-" + i,
                                  false, categoryId, i, c, isPrivate)
                }
            }
        }

        function appendMember(model, pubKey, memberName, index, role) {
            model.append({
                pubKey: pubKey,
                compressedPubKey: "zQ3" + pubKey,
                displayName: memberName,
                preferredDisplayName: memberName,
                ensName: "",
                isEnsVerified: false,
                localNickname: "",
                alias: "three word alias",
                icon: "",
                colorId: index % 10,
                onlineStatus: index % 2,
                isContact: false,
                isVerified: false,
                isUntrustworthy: false,
                isBlocked: false,
                isAdmin: role === Constants.memberRole.admin,
                memberRole: role,
                isCurrentUser: pubKey === "0xdeadbeef",
                contactRequest: 0,
                emojiHash: JSON.stringify(["👨🏻‍🍼", "🏃🏿‍♂️", "🌇", "🤶🏿", "🏮", "🤷🏻‍♂️", "🤦🏻",
                                           "📣", "🤎", "👷🏽", "😺", "🥞", "🔃", "🧝🏽‍♂️"]),
                trustStatus: 0,
                usesDefaultName: false,
                joined: true
            })
        }

        function buildMembers() {
            root.membersModel.clear()
            root.privateChannelMembersModel.clear()
            appendMember(root.membersModel, "0xdeadbeef", "Me", 0, root.memberRole)
            for (let i = 0; i < root.membersCount; ++i) {
                const role = i === 0 ? Constants.memberRole.owner : Constants.memberRole.none
                appendMember(root.membersModel, "0xmember-" + i, "Member " + i, i + 1, role)
            }
            appendMember(root.privateChannelMembersModel, "0xdeadbeef", "Me", 0, root.memberRole)
            for (let i = 0; i < root.privateChannelMembersCount; ++i)
                appendMember(root.privateChannelMembersModel, "0xmember-" + i, "Member " + i, i + 1,
                             i === 0 ? Constants.memberRole.owner : Constants.memberRole.none)
        }

        function privateChannelIds() {
            const ids = []
            for (const chatId in d.chatInfo) {
                if (d.chatInfo[chatId].requiresPermissions)
                    ids.push(chatId)
            }
            return ids
        }

        // Mirrors entries of the AssetsModel mock (which fills itself only on
        // Component.onCompleted, possibly after the first rebuild() call)
        readonly property var holdingTokens: [
            { key: "socks", symbol: "SOCKS", shortName: "SOCKS", name: "Unisocks" },
            { key: "zrx", symbol: "ZRX", shortName: "ZRX", name: "Ox" },
            { key: "1inch", symbol: "1INCH", shortName: "1INCH", name: "1inch" },
            { key: "eth", symbol: "ETH", shortName: "eth", name: "eth" }
        ]

        function appendPermission(index, permissionType, channelIds) {
            const id = "permission-" + index
            const asset = holdingTokens[index % holdingTokens.length]
            root.permissionsModel.append({
                id: id,
                key: id,
                permissionType: permissionType,
                holdingsListModel: [{
                    key: asset.key,
                    type: Constants.TokenType.ERC20,
                    symbol: asset.symbol,
                    shortName: asset.shortName,
                    name: asset.name,
                    amount: "" + (10 * (index + 1)),
                    available: true
                }],
                channelsListModel: channelIds.map(chatId => ({
                    key: chatId,
                    channelName: d.chatInfo[chatId].name
                })),
                isPrivate: root.permissionsArePrivate,
                tokenCriteriaMet: root.tokenCriteriaMet,
                permissionState: 0
            })
            root.permissionsModel.channelMap[id] = channelIds
        }

        function buildPermissions() {
            root.permissionsModel.clear()
            root.permissionsModel.channelMap = ({})
            let index = 0
            for (let i = 0; i < root.becomeMemberPermissionsCount; ++i)
                appendPermission(index++, Constants.permissionType.member, [])
            const gated = privateChannelIds()
            for (let i = 0; i < root.viewOnlyPermissionsCount; ++i)
                appendPermission(index++, Constants.permissionType.read, gated)
            for (let i = 0; i < root.viewAndPostPermissionsCount; ++i)
                appendPermission(index++, Constants.permissionType.viewAndPost, gated)
        }

        function fillMessages(model, chatId) {
            const now = Date.now()
            const count = root.messagesPerChannel
            const senderCount = Math.max(1, Math.min(root.membersCount, 20))
            // like the production model: index 0 is the newest message and
            // history grows towards higher indexes
            for (let i = 0; i < count; ++i) {
                const own = i % 7 === 1
                const senderIdx = i % senderCount
                const ts = now - i * 60000
                model.append({
                    id: "msg-" + chatId + "-" + i,
                    prevMsgIndex: i + 1,
                    nextMsgIndex: i - 1,
                    prevMsgTimestamp: ts - 60000,
                    nextMsgTimestamp: ts + 60000,
                    prevMsgSenderId: "",
                    prevMsgContentType: Constants.messageContentType.messageType,
                    prevMsgDeleted: false,
                    timestamp: ts,
                    responseToMessageWithId: "",
                    senderId: own ? "0xdeadbeef" : "0xmember-" + senderIdx,
                    senderDisplayName: own ? "Me" : "Member " + senderIdx,
                    senderOptionalName: "",
                    senderIcon: "",
                    senderIsAdded: true,
                    senderEnsVerified: false,
                    senderTrustStatus: 0,
                    amISender: own,
                    messageText: "Message " + (count - i) + " — the quick brown fox jumps over the lazy dog. "
                                 + (i % 5 === 0 ? "A somewhat longer paragraph to vary the bubble heights while measuring text. " : ""),
                    unparsedText: "Message " + (count - i),
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
                    communityId: root.communityId,
                    compressedKey: "",
                    bridgeName: "",
                    albumMessageImages: "",
                    albumImagesCount: 0,
                    usesDefaultName: false
                })
            }
        }

        // Message history is filled lazily on first activation, mirroring the
        // backend and keeping inactive channels out of measured load windows
        function contentModuleFor(chatId) {
            if (chatId === "" || !d.chatInfo[chatId])
                return null
            if (!d.contentModules[chatId]) {
                d.contentModules[chatId] = root.contentModuleComponent.createObject(root, {
                    chatId: chatId,
                    info: d.chatInfo[chatId]
                })
            }
            return d.contentModules[chatId]
        }

        function destroyContentModules() {
            for (const chatId in d.contentModules)
                d.contentModules[chatId].destroy()
            d.contentModules = ({})
            d.preparedChatId = ""
        }
    }

    function firstChannelId() {
        return uncategorizedChannelsCount > 0 ? "channel-u-0"
             : (categoriesCount > 0 && channelsPerCategory > 0 ? "channel-0-0" : "")
    }

    function firstPrivateChannelId() {
        const ids = d.privateChannelIds()
        return ids.length > 0 ? ids[0] : ""
    }

    function setCategoryOpened(categoryId, opened) {
        for (let i = 0; i < chatsModel.count; ++i) {
            if (chatsModel.get(i).categoryId === categoryId)
                chatsModel.setProperty(i, "categoryOpened", opened)
        }
    }

    // Only touches the rows that change, like the nim model does — a
    // full-model write storm would bill SFPM/ListView invalidation work to
    // whatever loads next
    function setActiveChat(id) {
        for (let i = 0; i < chatsModel.count; ++i) {
            const row = chatsModel.get(i)
            const isActive = row.itemId === id
            if (row.active !== isActive) {
                chatsModel.setProperty(i, "active", isActive)
                chatsModel.setProperty(i, "selected", isActive)
            }
            if (isActive && !row.loaderActive)
                chatsModel.setProperty(i, "loaderActive", true)
        }
        activeChatId = id
        sectionModule.activeItem = ({ id: id, type: Constants.chatType.communityChat })
        const module = d.contentModuleFor(id)
        if (module && !module.messagesModel) {
            module.messagesModel = messagesModelComponent.createObject(module)
            d.fillMessages(module.messagesModel, id)
        }
        ChatStores.ChatStoresConfig.currentChatContentModule = module
        ChatStores.ChatStoresConfig.usersModel = module && module.info.requiresPermissions
                ? privateChannelMembersModel
                : membersModel
    }

    function rebuild() {
        d.destroyContentModules()
        activeChatId = ""
        sectionModule.activeItem = ({ id: "", type: -1 })
        d.buildChats()
        d.buildMembers()
        d.buildPermissions()
    }

    function install() {
        rebuild()
        ChatStores.ChatStoresConfig.chatSectionModule = sectionModule
        ChatStores.ChatStoresConfig.sectionDetails = sectionItemModel
        ChatStores.ChatStoresConfig.assetsModel = assetsModel
        ChatStores.ChatStoresConfig.collectiblesModel = collectiblesModel
        MessagingStores.MessagingStoresConfig.communityRootStoreFactory =
                (parent, communityId) => {
                    // this mock backs exactly one community; a store built here
                    // for any other id would be silently wrong
                    if (communityId !== root.communityId)
                        console.warn("CommunitySectionMock: communityRootStoreFactory asked for",
                                     communityId, "but the mock is wired for", root.communityId)
                    return communityRootStoreComponent.createObject(parent)
                }
        const first = firstChannelId()
        if (first !== "")
            setActiveChat(first)
    }

    function uninstall() {
        ChatStores.ChatStoresConfig.chatSectionModule = null
        ChatStores.ChatStoresConfig.currentChatContentModule = null
        ChatStores.ChatStoresConfig.usersModel = null
        ChatStores.ChatStoresConfig.sectionDetails = null
        ChatStores.ChatStoresConfig.assetsModel = null
        ChatStores.ChatStoresConfig.collectiblesModel = null
        MessagingStores.MessagingStoresConfig.communityRootStoreFactory = null
        d.destroyContentModules()
    }
}
