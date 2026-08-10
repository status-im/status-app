import QtQuick
import QtTest

import utils

import Models

import shared.stores as SharedStores
import shared.stores.send as SendStores

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.Communities.stores as CommunitiesStores
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.stores.Messaging as MessagingStores

import mainui.adaptors
import mainui.sectionLoaders

// Regression tests for the chrome-inverted CommunityChatLoader driven by the
// configurable CommunitySectionMock: join-state routing (joined / token-gated
// / banned / owner-offline), private channels and their members, and section
// load cost guards.
Item {
    id: root

    width: 1000
    height: 700

    CommunitySectionMock { id: mock }

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
    CommunitiesStores.CommunitiesStore { id: communitiesStoreMock }
    MessagingStores.MessagingRootStore { id: messagingRootStoreMock }
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

        sourceComponent: CommunityChatLoader {
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
            communitiesStore: communitiesStoreMock
            messagingRootStore: messagingRootStoreMock
            createChatPropertiesStore: createChatPropertiesStoreMock
            contactsAdaptor: contactsAdaptorMock
            popupHandler: null
            emojiPopupLoader: emojiPopupLoaderMock
            stickersPopupLoader: stickersPopupLoaderMock
            sectionId: mock.communityId
            sectionItemModel: mock.sectionItemModel
            createChatViewOpened: false
            isPortraitMode: false
        }
    }

    TestCase {
        name: "CommunityChatLoaderSection"
        when: windowShown

        function init() {
            // baseline config: joined member of a token-gated community with
            // categories, one private channel per category and permissions
            mock.joined = true
            mock.memberRole = Constants.memberRole.none
            mock.amIBanned = false
            mock.requestToJoinState = Constants.RequestToJoinState.None
            mock.requiresTokenPermissionToJoin = true
            mock.isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin = false
            mock.membersCount = 50
            mock.categoriesCount = 2
            mock.channelsPerCategory = 5
            mock.uncategorizedChannelsCount = 2
            mock.privateChannelsPerCategory = 1
            mock.privateChannelMembersCount = 10
            mock.messagesPerChannel = 150
            mock.canViewPrivateChannels = true
            mock.canPostInPrivateChannels = true
            mock.install()
        }

        function cleanup() {
            harness.active = false
            mock.uninstall()
        }

        function findAllByTypePrefix(item, prefix, out) {
            if (!item)
                return out
            if (item.toString().indexOf(prefix) === 0)
                out.push(item)
            const list = item.children
            for (let i = 0; i < list.length; ++i)
                findAllByTypePrefix(list[i], prefix, out)
            return out
        }

        // like findAllByTypePrefix, but through `data` so non-visual children
        // (popups, tooltips) are found too
        function findAllInDataByTypePrefix(obj, prefix, out) {
            if (!obj)
                return out
            if (obj.toString().indexOf(prefix) === 0)
                out.push(obj)
            const list = obj.data ?? []
            for (let i = 0; i < list.length; ++i)
                findAllInDataByTypePrefix(list[i], prefix, out)
            return out
        }

        function findChildByTypePrefix(item, prefix) {
            if (!item)
                return null
            if (item.toString().indexOf(prefix) === 0)
                return item
            const list = item.children
            for (let i = 0; i < list.length; ++i) {
                const found = findChildByTypePrefix(list[i], prefix)
                if (found)
                    return found
            }
            return null
        }

        function loadSection() {
            harness.active = true
            const loader = harness.item
            verify(!!loader)
            tryVerify(() => loader.status === Loader.Ready, 120000)
            return loader
        }

        // Joined member: skeleton chrome first, then the real paneled chat
        // view with the categorized channels list, virtualized.
        function test_joinedCommunityLoadsRealSectionAfterSkeleton() {
            harness.active = true
            const loader = harness.item
            verify(!!loader)

            // while incubating, the loader-owned chrome shows the skeleton
            const skeleton = findChildByTypePrefix(loader, "CommunityChannelsSkeleton")
            verify(!!skeleton)
            verify(skeleton.visible)

            tryVerify(() => loader.status === Loader.Ready, 120000)
            verify(!loader.item.ownsFullPage,
                   "a joined member must get the paneled chat view")
            tryVerify(() => loader.item.leftPanel !== null, 10000)

            const chatList = findChild(loader, "chatListItems")
            verify(!!chatList)
            // category headers and channels are both rows of the list
            const rows = mock.uncategorizedChannelsCount + mock.categoriesCount
                       + mock.categoriesCount * mock.channelsPerCategory
            tryCompare(chatList, "count", rows)
        }

        // Each channel-list row must build only its own row type: chat rows
        // must not carry a hidden category item and vice versa.
        function test_channelRowsBuildOnlyTheirRowType() {
            const loader = loadSection()

            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            const rows = mock.uncategorizedChannelsCount + mock.categoriesCount
                       + mock.categoriesCount * mock.channelsPerCategory
            tryCompare(lv, "count", rows)
            waitForRendering(lv)

            const categoryItems =
                findAllByTypePrefix(lv.contentItem, "StatusChatListCategoryItem_QMLTYPE", [])
            const chatItems =
                findAllByTypePrefix(lv.contentItem, "StatusChatListItem_QMLTYPE", [])

            compare(categoryItems.length, mock.categoriesCount,
                    "one category item per category row, no hidden twins")
            compare(chatItems.length, rows - mock.categoriesCount,
                    "one chat item per channel row, no hidden twins")

            // hover/state chrome is lazy: nothing is muted, so chat rows must
            // not build the unmute tooltip (category action buttons keep
            // their own — the button tooltip is public API)
            for (let i = 0; i < chatItems.length; ++i) {
                compare(findAllInDataByTypePrefix(chatItems[i], "StatusToolTip_QMLTYPE", []).length, 0,
                        "unmuted chat rows must not build the unmute tooltip")
            }
        }

        // Members get a virtualized channels list: only viewport+cache rows
        // may be built, never one per channel.
        function test_memberChannelsListVirtualized() {
            mock.categoriesCount = 10
            mock.channelsPerCategory = 20
            mock.install()

            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            const rows = mock.uncategorizedChannelsCount + mock.categoriesCount
                       + mock.categoriesCount * mock.channelsPerCategory
            tryCompare(lv, "count", rows)
            waitForRendering(lv)

            const created = lv.contentItem.children.length
            verify(created > 0, "some channel rows must be built")
            verify(created < 60,
                   "member channels list must be virtualized, got " + created
                   + " of " + lv.count)
        }

        function clickableChatRow(lv) {
            const chatItems = findAllByTypePrefix(lv.contentItem, "StatusChatListItem_QMLTYPE", [])
            for (let i = 0; i < chatItems.length; ++i) {
                const item = chatItems[i]
                if (item.chatId !== mock.activeChatId && item.visible && item.height > 0)
                    return item
            }
            return null
        }

        // Clicking a channel row must select it (regression: with the drag
        // wrapper gone for members, rows must handle their own clicks).
        function test_clickSelectsChannel() {
            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            const row = clickableChatRow(lv)
            verify(!!row, "a non-active channel row must exist")
            const clickedId = row.chatId
            mouseClick(row)
            tryVerify(() => mock.activeChatId === clickedId, 5000,
                      "clicking a channel must select it, active: " + mock.activeChatId)
        }

        // Admin drag-and-drop: dragging the first channel one row down must
        // reorder it to the next position — not require dragging far past it.
        function test_adminDragReordersToAdjacentRow() {
            mock.memberRole = Constants.memberRole.owner
            mock.install()
            mock.sectionModule.lastReorder = null

            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            const rows = findAllByTypePrefix(lv.contentItem, "StatusChatListItem_QMLTYPE", [])
            verify(rows.length >= 2)
            rows.sort((a, b) => a.mapToItem(null, 0, 0).y - b.mapToItem(null, 0, 0).y)
            const first = rows[0]
            const second = rows[1]
            const firstId = first.chatId
            const rowH = first.height

            // press on the first row and drag to the middle of the second
            // row, in the STATIC list's coordinates (the dragged row moves —
            // item-relative coordinates would chase it)
            const start = first.mapToItem(lv, first.width / 2, first.height / 2)
            mousePress(lv, start.x, start.y)
            for (let step = 1; step <= 8; ++step) {
                mouseMove(lv, start.x, start.y + (rowH * 1.2 * step) / 8)
                wait(20)
            }
            mouseRelease(lv, start.x, start.y + rowH * 1.2)
            waitForRendering(lv)

            tryVerify(() => !!mock.sectionModule.lastReorder, 3000,
                      "drag one row down must trigger a reorder")
            compare(mock.sectionModule.lastReorder.chatId, firstId)
            compare(mock.sectionModule.lastReorder.to, second.position !== undefined
                    ? second.position : 1,
                    "reorder target must be the adjacent row's position")
        }

        // Upward drags cross the enclosing ScrollView's flick threshold while
        // the content can still scroll — the Flickable must not steal the
        // grab from an active row drag.
        function test_adminDragReordersUpward() {
            mock.memberRole = Constants.memberRole.owner
            // overflow the viewport: the enclosing ScrollView only steals
            // drags when it has somewhere to scroll
            mock.categoriesCount = 4
            mock.channelsPerCategory = 6
            mock.install()
            mock.sectionModule.lastReorder = null

            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            const rows = findAllByTypePrefix(lv.contentItem, "StatusChatListItem_QMLTYPE", [])
            verify(rows.length >= 2)
            rows.sort((a, b) => a.mapToItem(null, 0, 0).y - b.mapToItem(null, 0, 0).y)
            const first = rows[0]
            const second = rows[1]
            const secondId = second.chatId
            const rowH = second.height

            const start = second.mapToItem(lv, second.width / 2, second.height / 2)
            mousePress(lv, start.x, start.y)
            for (let step = 1; step <= 8; ++step) {
                mouseMove(lv, start.x, start.y - (rowH * 1.2 * step) / 8)
                wait(20)
            }
            mouseRelease(lv, start.x, start.y - rowH * 1.2)
            waitForRendering(lv)

            tryVerify(() => !!mock.sectionModule.lastReorder, 3000,
                      "drag one row up must trigger a reorder")
            compare(mock.sectionModule.lastReorder.chatId, secondId)
            compare(mock.sectionModule.lastReorder.to, first.position !== undefined
                    ? first.position : 0,
                    "reorder target must be the adjacent row's position")
        }

        // The mock must apply reorders to its model so storybook drags give
        // visual feedback (the real backend reorders and pushes a new model).
        function test_reorderAppliesToModel() {
            mock.memberRole = Constants.memberRole.owner
            mock.install()

            mock.sectionModule.reorderCommunityChat("", "channel-u-0", 1)
            compare(mock.chatsModel.get(0).itemId, "channel-u-1",
                    "the displaced row must move up")
            compare(mock.chatsModel.get(0).position, 0)
            compare(mock.chatsModel.get(1).itemId, "channel-u-0",
                    "the reordered row must land at its target position")
            compare(mock.chatsModel.get(1).position, 1)
        }

        // The enclosing Flickable force-cancels a drag's grab once movement
        // crosses its flick threshold (real pointer input only, so the cancel
        // itself is untestable here) — row drags must freeze it instead.
        function test_dragFreezesEnclosingFlickable() {
            mock.memberRole = Constants.memberRole.owner
            mock.categoriesCount = 4
            mock.channelsPerCategory = 6
            mock.install()

            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            let flick = null
            for (let p = lv.parent; p; p = p.parent) {
                if (p instanceof Flickable && p.interactive) {
                    flick = p
                    break
                }
            }
            verify(!!flick, "the admin list must sit in an interactive Flickable")

            const rows = findAllByTypePrefix(lv.contentItem, "StatusChatListItem_QMLTYPE", [])
            verify(rows.length >= 2)
            rows.sort((a, b) => a.mapToItem(null, 0, 0).y - b.mapToItem(null, 0, 0).y)
            const first = rows[0]
            const rowH = first.height

            const start = first.mapToItem(lv, first.width / 2, first.height / 2)
            mousePress(lv, start.x, start.y)
            let frozen = false
            for (let step = 1; step <= 8; ++step) {
                mouseMove(lv, start.x, start.y + (rowH * 1.2 * step) / 8)
                wait(20)
                frozen = frozen || !flick.interactive
            }
            verify(frozen, "the enclosing Flickable must be frozen while a row drag is active")
            mouseRelease(lv, start.x, start.y + rowH * 1.2)
            waitForRendering(lv)
            tryVerify(() => flick.interactive, 2000,
                      "the enclosing Flickable must be restored after the drag")
        }

        // Same for admins, whose rows keep the draggable wrapper.
        function test_clickSelectsChannelAsAdmin() {
            mock.memberRole = Constants.memberRole.owner
            mock.install()

            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            const row = clickableChatRow(lv)
            verify(!!row, "a non-active channel row must exist")
            const clickedId = row.chatId
            mouseClick(row)
            tryVerify(() => mock.activeChatId === clickedId, 5000,
                      "clicking a channel must select it, active: " + mock.activeChatId)
        }

        // Clicking a category row must collapse/expand it.
        function test_clickTogglesCategory() {
            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            const categoryItems =
                findAllByTypePrefix(lv.contentItem, "StatusChatListCategoryItem_QMLTYPE", [])
            verify(categoryItems.length > 0, "a category row must exist")
            const category = categoryItems[0]
            verify(category.opened)
            mouseClick(category)
            tryVerify(() => !category.opened, 5000,
                      "clicking a category must collapse it")
        }

        // Device repro: portrait mode, tap channel (goes to center panel),
        // swipe back, tap the channel above — the tap must select it and
        // navigate; a stale scroll state shifting rows mid-press breaks it.
        function test_portraitTapAfterPanelRoundtrip() {
            harness.active = true
            const loader = harness.item
            verify(!!loader)
            loader.isPortraitMode = true
            tryVerify(() => loader.status === Loader.Ready, 120000)

            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            const layout = findChild(loader, "sectionLayout")
                        ?? loader.children[0]

            function rowByChatId(id) {
                const items = findAllByTypePrefix(lv.contentItem, "StatusChatListItem_QMLTYPE", [])
                for (let i = 0; i < items.length; ++i) {
                    if (items[i].chatId === id)
                        return items[i]
                }
                return null
            }

            for (let round = 0; round < 3; ++round) {
                // tap an unselected channel; must select and go to center
                const target = clickableChatRow(lv)
                verify(!!target, "round " + round + ": need a clickable row")
                const targetId = target.chatId
                const sceneYBefore = target.mapToItem(null, 0, 0).y
                mouseClick(target)
                tryVerify(() => mock.activeChatId === targetId, 5000,
                          "round " + round + ": tap must select " + targetId
                          + " (row sceneY was " + sceneYBefore + ", now "
                          + (rowByChatId(targetId)
                             ? rowByChatId(targetId).mapToItem(null, 0, 0).y
                             : "gone") + ")")

                // back to the channels panel, like the swipe-back gesture
                loader.item.sectionLayout.goToPreviousPanel()
                waitForRendering(lv)
                wait(100)
            }
        }

        // Regular members can't reorder channels — their rows must not carry
        // the drag-and-drop machinery (DropArea + draggable wrapper).
        function test_memberRowsSkipDragMachinery() {
            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            compare(findAllByTypePrefix(lv.contentItem, "StatusDraggableListItem", []).length, 0,
                    "member rows must not build the draggable wrapper")
            compare(findAllByTypePrefix(lv.contentItem, "QQuickDropArea", []).length, 0,
                    "member rows must not build drop areas")
        }

        // Admins keep the full drag-and-drop machinery.
        function test_adminRowsKeepDragMachinery() {
            mock.memberRole = Constants.memberRole.owner
            mock.install()

            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            verify(findAllByTypePrefix(lv.contentItem, "StatusDraggableListItem", []).length > 0,
                   "admin rows must keep the draggable wrapper")
            verify(findAllByTypePrefix(lv.contentItem, "QQuickDropArea", []).length > 0,
                   "admin rows must keep drop areas")
        }

        // Token-gated community I have not joined: the join view owns the
        // full page and the loader chrome is hidden.
        function test_tokenGatedNonMemberShowsJoinFullPage() {
            mock.joined = false
            mock.install()

            const loader = loadSection()
            tryVerify(() => loader.item.ownsFullPage, 10000)

            tryVerify(() => !!findChildByTypePrefix(loader, "JoinCommunityView"), 10000,
                      "non-member of a token-gated community must see JoinCommunityView")
        }

        // Banned member: banned view owns the full page.
        function test_bannedMemberShowsBannedFullPage() {
            mock.joined = false
            mock.amIBanned = true
            mock.install()

            const loader = loadSection()
            tryVerify(() => loader.item.ownsFullPage, 10000)
            tryVerify(() => !!findChildByTypePrefix(loader, "BannedMemberCommunityView"), 10000,
                      "banned member must see BannedMemberCommunityView")
        }

        // Waiting on the new owner to confirm the request to rejoin: control
        // node offline view owns the full page.
        function test_ownerOfflineShowsControlNodeFullPage() {
            mock.joined = false
            mock.isWaitingOnNewCommunityOwnerToConfirmRequestToRejoin = true
            mock.install()

            const loader = loadSection()
            tryVerify(() => loader.item.ownsFullPage, 10000)
            tryVerify(() => !!findChildByTypePrefix(loader, "ControlNodeOfflineCommunityView"), 10000,
                      "must see ControlNodeOfflineCommunityView while the owner is offline")
        }

        // Private (token-gated) channels expose their own members list, not
        // the whole community's.
        function test_privateChannelUsesItsOwnMembers() {
            const loader = loadSection()

            // public channel: community members (+ me)
            tryVerify(() => !!loader.item.usersModel, 10000)
            compare(loader.item.usersModel.count, mock.membersCount + 1)

            const privateId = mock.firstPrivateChannelId()
            verify(privateId !== "", "config must produce a private channel")
            mock.setActiveChat(privateId)

            tryVerify(() => loader.item.usersModel.count === mock.privateChannelMembersCount + 1,
                      10000, "private channel must use its own members model")
        }

        // Load-time guard against crawl regressions when the community scale
        // grows: with the member channels list virtualized, load cost must be
        // near-independent of the channel count.
        function test_sectionLoadCostBoundedWithScale() {
            function measureSectionLoad() {
                mock.install()
                const t0 = Date.now()
                harness.active = true
                const loader = harness.item
                tryVerify(() => loader.status === Loader.Ready, 120000)
                tryVerify(() => !!findChild(loader, "chatListItems"), 10000)
                waitForRendering(loader)
                const lv = findChild(loader, "chatListItems")
                const result = { ms: Date.now() - t0,
                                 rows: lv.contentItem.children.length }
                harness.active = false
                return result
            }

            measureSectionLoad() // warmup: first load pays QML compilation

            const small = measureSectionLoad()

            mock.membersCount = 2000
            mock.categoriesCount = 10
            mock.channelsPerCategory = 20
            mock.privateChannelsPerCategory = 4
            mock.messagesPerChannel = 2000
            const large = measureSectionLoad()

            console.info("community load cost: small =", small.ms, "ms /",
                         small.rows, "rows; large =", large.ms, "ms /",
                         large.rows, "rows")

            verify(large.rows < 60,
                   "only viewport+cache channel rows may be built, got " + large.rows)
            // generous CI headroom; a crawl regression is 5-50x, not 1.5x
            verify(large.ms < small.ms * 1.5 + 500,
                   "section load cost grew with community size: " + small.ms
                   + " ms small vs " + large.ms + " ms large")
        }
    }
}
