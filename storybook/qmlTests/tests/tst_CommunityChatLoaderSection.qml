import QtQuick
import QtQuick.Controls as QC
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
            root.height = 700
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
            tryVerify(() => loader.status === Loader.Ready, 10000)
            return loader
        }

        // Joined member: skeleton chrome first, then the real paneled chat
        // view with the categorized channels list.
        function test_joinedCommunityLoadsRealSectionAfterSkeleton() {
            harness.active = true
            const loader = harness.item
            verify(!!loader)

            // while incubating, the loader-owned chrome shows the skeleton
            const skeleton = findChildByTypePrefix(loader, "CommunityChannelsSkeleton")
            verify(!!skeleton)
            verify(skeleton.visible)

            tryVerify(() => loader.status === Loader.Ready, 10000)
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

        // The channels column and the message view incubate off the critical
        // path, so the loader-owned chrome keeps painting its skeletons while
        // they build and each slot swaps on its own panel's readiness. Both
        // panels finish within a single incubation slice here — virtualized
        // lists and the latched message model are that cheap — so what is
        // pinned is the contract, not a timing window.
        function test_panelsIncubateAsynchronously() {
            mock.categoriesCount = 10
            mock.channelsPerCategory = 20
            mock.messagesPerChannel = 2000
            mock.install()

            harness.active = true
            const loader = harness.item
            verify(!!loader)
            verify(findChildByTypePrefix(loader, "CommunityChannelsSkeleton").visible)

            tryVerify(() => loader.status === Loader.Ready, 10000)
            const view = loader.item
            verify(view.leftPanel.asynchronous,
                   "the channels column must incubate asynchronously")
            verify(view.centerPanel.asynchronous,
                   "the message view must incubate asynchronously")

            tryVerify(() => view.headerReady && view.leftPanelReady
                            && view.centerPanelReady, 60000,
                      "every panel must finish incubating")
            tryVerify(() => !findChildByTypePrefix(loader, "CommunityChannelsSkeleton"),
                      10000, "no slot may keep its skeleton once its panel is ready")
        }

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

        // Admins get the same virtualized list — reordering works within the
        // viewport, so the whole list no longer needs to be expanded for DnD.
        function test_adminChannelsListVirtualized() {
            mock.memberRole = Constants.memberRole.owner
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
                   "admin channels list must be virtualized, got " + created
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

        function test_clickTogglesCategory() {
            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)

            const categoryItems =
                findAllByTypePrefix(lv.contentItem, "StatusChatListCategoryItem_QMLTYPE", [])
            verify(categoryItems.length > 0, "a category row must exist")
            // every row hosts both item types; only category rows show theirs
            const category = categoryItems.filter(c => c.visible)[0]
            verify(!!category)
            verify(category.opened)
            mouseClick(category)
            tryVerify(() => !category.opened, 5000,
                      "clicking a category must collapse it")
        }

        // Rows keep materializing while the panels incubate asynchronously;
        // a drag choreographed against rows that then shift mid-gesture never
        // crosses its reorder threshold. Settle = row count and the top row's
        // scene position unchanged between two consecutive polls.
        // The drag's synthesized mouse-move pacing collapses while the other
        // panels are still incubating (event-loop starvation coalesces the
        // moves); wait for every panel to be real before starting a gesture.
        function waitForSectionReady(loader) {
            tryVerify(() => !!loader.item
                          && loader.item.headerReady
                          && loader.item.leftPanelReady
                          && loader.item.centerPanelReady
                          && loader.item.rightPanelReady, 60000,
                      "all panels must be ready before gesture tests")
        }

        function waitForStableRows(lv) {
            let prevCount = -1
            let prevY = -1e9
            tryVerify(() => {
                const rows = findAllByTypePrefix(lv.contentItem, "StatusChatListItem_QMLTYPE", [])
                    .filter(r => r.visible && r.height > 0)
                if (rows.length < 2) {
                    prevCount = -1
                    return false
                }
                rows.sort((a, b) => a.mapToItem(null, 0, 0).y - b.mapToItem(null, 0, 0).y)
                const y = rows[0].mapToItem(null, 0, 0).y
                const stable = rows.length === prevCount && y === prevY
                prevCount = rows.length
                prevY = y
                return stable
            }, 10000, "chat rows must settle before dragging")
        }

        function test_adminDragReordersToAdjacentRow() {
            mock.memberRole = Constants.memberRole.owner
            // gesture test: the message payload is irrelevant and its
            // incubation churn under the drag destabilizes the synthesized
            // mouse sequence
            mock.messagesPerChannel = 1
            mock.install()
            mock.sectionModule.lastReorder = null

            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)
            waitForSectionReady(loader)
            waitForStableRows(lv)

            const rows = findAllByTypePrefix(lv.contentItem, "StatusChatListItem_QMLTYPE", [])
                .filter(r => r.visible && r.height > 0)
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
            for (let step = 1; step <= 8; ++step)
                mouseMove(lv, start.x, start.y + (rowH * 1.2 * step) / 8, 20)
            // a frame between the last move and the release lets the drop
            // target process the final position before the drop lands
            waitForRendering(lv)
            mouseRelease(lv, start.x, start.y + rowH * 1.2)
            waitForRendering(lv)

            tryVerify(() => !!mock.sectionModule.lastReorder, 3000,
                      "drag one row down must trigger a reorder")
            compare(mock.sectionModule.lastReorder.chatId, firstId)
            compare(mock.sectionModule.lastReorder.to, second.position !== undefined
                    ? second.position : 1,
                    "reorder target must be the adjacent row's position")
        }

        function test_adminDragReordersUpward() {
            mock.memberRole = Constants.memberRole.owner
            // gesture test: the message payload is irrelevant and its
            // incubation churn under the drag destabilizes the synthesized
            // mouse sequence
            mock.messagesPerChannel = 1
            // overflow the viewport: the list only tries to steal drags for
            // flicking when it has somewhere to scroll
            mock.categoriesCount = 4
            mock.channelsPerCategory = 6
            mock.install()
            mock.sectionModule.lastReorder = null

            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)
            waitForSectionReady(loader)
            waitForStableRows(lv)

            const rows = findAllByTypePrefix(lv.contentItem, "StatusChatListItem_QMLTYPE", [])
                .filter(r => r.visible && r.height > 0)
            verify(rows.length >= 2)
            rows.sort((a, b) => a.mapToItem(null, 0, 0).y - b.mapToItem(null, 0, 0).y)
            const first = rows[0]
            const second = rows[1]
            const secondId = second.chatId
            const rowH = second.height

            const start = second.mapToItem(lv, second.width / 2, second.height / 2)
            mousePress(lv, start.x, start.y)
            for (let step = 1; step <= 8; ++step)
                mouseMove(lv, start.x, start.y - (rowH * 1.2 * step) / 8, 20)
            // a frame between the last move and the release lets the drop
            // target process the final position before the drop lands
            waitForRendering(lv)
            mouseRelease(lv, start.x, start.y - rowH * 1.2)
            waitForRendering(lv)

            tryVerify(() => !!mock.sectionModule.lastReorder, 3000,
                      "drag one row up must trigger a reorder")
            compare(mock.sectionModule.lastReorder.chatId, secondId)
            compare(mock.sectionModule.lastReorder.to, first.position !== undefined
                    ? first.position : 0,
                    "reorder target must be the adjacent row's position")
        }

        // The admin banners live below the channels as the list footer, so
        // they scroll with the content instead of an outer ScrollView.
        function test_adminSeesBannersAsListFooter() {
            mock.memberRole = Constants.memberRole.owner
            mock.install()

            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            tryVerify(() => !!lv.footerItem, 5000,
                      "admin list must instantiate the banner footer")
            lv.positionViewAtEnd()
            waitForRendering(lv)
            const banner = findChildByTypePrefix(lv.footerItem, "WelcomeBannerPanel")
            verify(!!banner, "the footer must hold the welcome banner")
            tryVerify(() => banner.visible)
        }

        // Right-clicking the empty area below the channels opens the admin
        // menu — repeatedly (the menu instance must survive closing).
        function test_adminEmptyAreaRightClickMenuReopens() {
            mock.memberRole = Constants.memberRole.owner
            mock.categoriesCount = 0
            mock.uncategorizedChannelsCount = 2
            mock.install()
            // the banner footer is tall — make sure empty space remains
            root.height = 1400

            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            waitForRendering(lv)
            tryVerify(() => lv.contentHeight > 0, 5000)
            verify(lv.contentHeight < lv.height - 10,
                   "config must leave empty space below the rows")

            const overlay = QC.Overlay.overlay
            function openPopupItem() {
                return Array.prototype.filter.call(overlay.children,
                    c => c.toString().indexOf("QQuickPopupItem") === 0 && c.visible)[0]
            }
            for (let round = 0; round < 2; ++round) {
                mouseClick(lv, lv.width / 2, lv.height - 5, Qt.RightButton)
                tryVerify(() => !!openPopupItem(), 2000,
                          "empty-area right-click must open the admin menu, round " + round)
                keyClick(Qt.Key_Escape)
                tryVerify(() => !openPopupItem())
            }
        }

        function test_memberHasNoBannerFooter() {
            const loader = loadSection()
            const lv = findChild(loader, "chatListItems")
            verify(!!lv)
            tryVerify(() => lv.count > 0, 10000)
            verify(!lv.footerItem, "members must not get the admin banner footer")
        }
        function test_sectionLoadCostBoundedWithScale() {
            function measureSectionLoad() {
                mock.install()
                harness.active = true
                const loader = harness.item
                tryVerify(() => loader.status === Loader.Ready, 10000)
                tryVerify(() => !!findChild(loader, "chatListItems"), 10000)
                waitForRendering(loader)
                const lv = findChild(loader, "chatListItems")
                const result = { rows: lv.contentItem.children.length }
                harness.active = false
                return result
            }

            measureSectionLoad() // warmup: first load pays QML compilation

            mock.membersCount = 2000
            mock.categoriesCount = 10
            mock.channelsPerCategory = 20
            mock.privateChannelsPerCategory = 4
            mock.messagesPerChannel = 2000
            const large = measureSectionLoad()

            verify(large.rows < 60,
                   "only viewport+cache channel rows may be built, got " + large.rows)
        }
    }
}
