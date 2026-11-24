import QtQuick
import QtTest

import AppLayouts.Communities
import AppLayouts.Communities.stores

import utils

Item {
    id: root

    width: 1000
    height: 800

    Component {
        id: layoutComponent

        CommunitiesPortalLayout {
            anchors.fill: parent

            assetsModel: ListModel {}
            collectiblesModel: ListModel {}
            communitiesStore: CommunitiesStore {
                readonly property string communityTags: "[]"
                readonly property ListModel curatedCommunitiesModel: ListModel {}
            }
        }
    }

    readonly property var community: ({
        id: "0x01", available: true, name: "Status", description: "", icon: "", banner: "",
        featured: false, members: 1, activeMembers: 1, popularity: 1, color: "blue",
        tags: "[]", amIBanned: false, joined: false, encrypted: false
    })

    SignalSpy {
        id: refreshSpy
        signalName: "curatedRefreshRequested"
    }

    TestCase {
        name: "CommunitiesPortalLayout"
        when: windowShown

        function createLayout() {
            const layout = createTemporaryObject(layoutComponent, root)
            verify(!!layout)
            const indicator = findChild(layout, "curatedCommunitiesLoadingIndicator")
            verify(!!indicator)
            refreshSpy.clear()
            refreshSpy.target = layout
            return { layout, indicator, store: layout.communitiesStore }
        }

        function createLoadedLayout(properties = {}) {
            const { layout, indicator, store } = createLayout()
            tryCompare(indicator, "active", false)
            for (const name in properties)
                layout[name] = properties[name]
            return { layout, store }
        }

        function errorPill(layout) {
            return findChild(layout, "curatedRefreshErrorPill")
        }

        function pull(grid) {
            mousePress(grid, 200, 50)
            for (let i = 1; i <= 10; i++)
                mouseMove(grid, 200, 50 + 40 * i)
            mouseRelease(grid, 200, 450)
        }

        function test_noErrorShowsNoPill() {
            const { layout } = createLoadedLayout()

            verify(!errorPill(layout))
        }

        function test_partialErrorIsShownAboveTheGrid() {
            const { layout, store } = createLoadedLayout()
            store.curatedCommunitiesModel.append(root.community)

            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Partial

            const pill = errorPill(layout)
            verify(!!pill)
            compare(pill.visible, true)
            compare(pill.text, "Some communities couldn't be loaded.")
            compare(findChild(layout, "curatedRefreshErrorLoader").active, true)
        }

        function test_fullErrorOverCardsIsShownAboveTheGrid() {
            const { layout, store } = createLoadedLayout()
            store.curatedCommunitiesModel.append(Object.assign({}, root.community, { available: false, name: "" }))

            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full

            compare(errorPill(layout).text, "Couldn't load communities.")
            compare(findChild(layout, "curatedRefreshErrorLoader").active, true)
        }

        function test_fullErrorOnAnEmptyGridIsShownAboveTheGrid() {
            const { layout, store } = createLoadedLayout()

            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full

            compare(findChild(layout, "curatedRefreshErrorLoader").active, true)
            compare(errorPill(layout).text, "Couldn't load communities.")
            compare(findChild(layout, "noCommunitiesFoundText").visible, true)
        }

        function gridY(layout) {
            const grid = findChild(layout, "curatedCommunitiesGrid")
            verify(!!grid)
            return grid.mapToItem(layout, 0, 0).y
        }

        function test_errorStaysWhileARefreshIsRunning() {
            const { layout, store } = createLoadedLayout({ pullToRefreshEnabled: true })
            store.curatedCommunitiesModel.append(root.community)
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Partial
            const loader = findChild(layout, "curatedRefreshErrorLoader")
            waitForRendering(errorPill(layout))
            const shownGridY = gridY(layout)

            store.curatedCommunitiesLoading = true
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.None
            compare(loader.active, true)
            compare(errorPill(layout).text, "Some communities couldn't be loaded. Pull to refresh.")
            waitForRendering(layout)
            compare(gridY(layout), shownGridY)

            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full
            store.curatedCommunitiesLoading = false
            compare(loader.active, true)
            compare(errorPill(layout).text, "Couldn't load communities. Pull to refresh.")
            waitForRendering(layout)
            compare(gridY(layout), shownGridY)
        }

        function test_errorCollapsesAfterASuccessfulRefresh() {
            const { layout, store } = createLoadedLayout({ pullToRefreshEnabled: true })
            const hiddenGridY = gridY(layout)
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full
            const loader = findChild(layout, "curatedRefreshErrorLoader")
            waitForRendering(errorPill(layout))
            const shownGridY = gridY(layout)
            verify(shownGridY > hiddenGridY)

            store.curatedCommunitiesLoading = true
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.None
            store.curatedCommunitiesLoading = false
            compare(loader.active, true)
            waitForRendering(layout)
            verify(gridY(layout) > hiddenGridY)

            tryCompare(loader, "active", false)
            waitForRendering(layout)
            compare(gridY(layout), hiddenGridY)
        }

        function test_errorShownAgainBeforeTheCollapseEnds() {
            const { layout, store } = createLoadedLayout()
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full
            const loader = findChild(layout, "curatedRefreshErrorLoader")
            waitForRendering(errorPill(layout))
            const shownGridY = gridY(layout)

            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.None
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Partial
            compare(loader.active, true)
            waitForRendering(layout)
            compare(gridY(layout), shownGridY)
            compare(errorPill(layout).text, "Some communities couldn't be loaded.")
        }

        function test_errorPosition_data() {
            return [
                { tag: "desktop, full, empty grid", width: 1000, pullToRefresh: false, cards: 0,
                  error: Constants.CuratedCommunitiesRefreshError.Full },
                { tag: "desktop, partial, cards", width: 1000, pullToRefresh: false, cards: 1,
                  error: Constants.CuratedCommunitiesRefreshError.Partial },
                { tag: "mobile, full, empty grid", width: 360, pullToRefresh: true, cards: 0,
                  error: Constants.CuratedCommunitiesRefreshError.Full },
                { tag: "mobile, partial, cards", width: 360, pullToRefresh: true, cards: 1,
                  error: Constants.CuratedCommunitiesRefreshError.Partial }
            ]
        }

        function test_errorPosition(data) {
            const { layout, store } = createLoadedLayout({ pullToRefreshEnabled: data.pullToRefresh })
            layout.anchors.fill = undefined
            layout.width = data.width
            for (let i = 0; i < data.cards; i++)
                store.curatedCommunitiesModel.append(root.community)
            store.curatedCommunitiesRefreshError = data.error
            const pill = errorPill(layout)
            verify(!!pill)
            waitForRendering(pill)

            const tags = findChild(layout, "communityTagsRow")
            const grid = findChild(layout, "curatedCommunitiesGrid")
            const promo = findChild(layout, "promotionalCommunityCard")
            verify(!!tags)
            verify(!!grid)
            verify(!!promo)
            const pillRect = pill.mapToItem(layout, 0, 0, pill.width, pill.height)
            const tagsRect = tags.mapToItem(layout, 0, 0, tags.width, tags.height)
            const gridRect = grid.mapToItem(layout, 0, 0, grid.width, grid.height)
            const promoRect = promo.mapToItem(layout, 0, 0, promo.width, promo.height)

            verify(pillRect.y >= tagsRect.y + tagsRect.height)
            verify(pillRect.y + pillRect.height <= gridRect.y)
            verify(pillRect.y + pillRect.height <= promoRect.y)
            fuzzyCompare(pillRect.x + pillRect.width / 2, tagsRect.x + tagsRect.width / 2, 1)
            verify(pillRect.x >= tagsRect.x)
            verify(pillRect.x + pillRect.width <= tagsRect.x + tagsRect.width)
            if (data.width > 600)
                verify(pillRect.width < tagsRect.width / 2)
        }

        function test_errorOffersRetryWithoutPullToRefresh() {
            const { layout, store } = createLoadedLayout()

            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full

            const button = findChild(errorPill(layout), "rightComponentButton")
            verify(!!button)
            compare(button.text, "Retry")
        }

        function test_errorNamesThePullWithPullToRefresh() {
            const { layout, store } = createLoadedLayout({ pullToRefreshEnabled: true })
            store.curatedCommunitiesModel.append(root.community)

            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Partial

            const pill = errorPill(layout)
            compare(pill.text, "Some communities couldn't be loaded. Pull to refresh.")
            verify(!findChild(pill, "rightComponentButton"))

            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full
            compare(errorPill(layout).text, "Couldn't load communities. Pull to refresh.")
        }

        function test_errorWrapsInANarrowPortal() {
            const { layout, store } = createLoadedLayout({ pullToRefreshEnabled: true })
            store.curatedCommunitiesModel.append(root.community)
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Partial
            const pill = errorPill(layout)
            waitForRendering(pill)
            const wideHeight = pill.height

            layout.anchors.fill = undefined
            layout.width = 300
            waitForRendering(pill)

            verify(pill.width < 300)
            verify(pill.height > wideHeight)
        }

        function test_clickOnTheErrorRequestsARefresh() {
            const { layout, store } = createLoadedLayout({ pullToRefreshEnabled: true })
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full

            const pill = errorPill(layout)
            waitForRendering(pill)
            mouseClick(pill)

            compare(refreshSpy.count, 1)
        }

        function test_clickOnTheErrorTextNextToRetryRequestsARefresh() {
            const { layout, store } = createLoadedLayout()
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full

            const pill = errorPill(layout)
            waitForRendering(pill)
            mouseClick(pill, 30, pill.height / 2)

            compare(refreshSpy.count, 1)
        }

        function test_clickOnRetryRequestsOneRefresh() {
            const { layout, store } = createLoadedLayout()
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full

            const button = findChild(errorPill(layout), "rightComponentButton")
            waitForRendering(button)
            mouseClick(button)

            compare(refreshSpy.count, 1)
        }

        function test_pullOnTheGridRequestsARefresh() {
            const { layout } = createLoadedLayout({ pullToRefreshEnabled: true })
            const grid = findChild(layout, "curatedCommunitiesGrid")
            verify(!!grid)

            pull(grid)

            compare(refreshSpy.count, 1)
        }

        function test_pullOnTheGridRequestsNothingWithoutPullToRefresh() {
            const { layout } = createLoadedLayout()

            pull(findChild(layout, "curatedCommunitiesGrid"))

            compare(refreshSpy.count, 0)
        }

        function test_refreshIndicatorIsShownForARequestedRefreshOnly() {
            const { layout, store } = createLoadedLayout({ pullToRefreshEnabled: true })
            store.curatedCommunitiesModel.append(root.community)
            const pullToRefresh = findChild(layout, "curatedPullToRefresh")
            verify(!!pullToRefresh)

            store.curatedCommunitiesLoading = true
            compare(pullToRefresh.refreshing, false)
            store.curatedCommunitiesLoading = false

            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Partial
            layout.curatedRefreshRequested.connect(() => store.curatedCommunitiesLoading = true)
            const pill = errorPill(layout)
            waitForRendering(pill)
            mouseClick(pill, 30, pill.height / 2)
            compare(pullToRefresh.refreshing, true)
            compare(pullToRefresh.visible, true)
            compare(pullToRefresh.parent, findChild(layout, "curatedCommunitiesGrid"))
            tryCompare(pullToRefresh, "opacity", 1)

            store.curatedCommunitiesLoading = false
            compare(pullToRefresh.refreshing, false)

            store.curatedCommunitiesLoading = true
            compare(pullToRefresh.refreshing, false)
        }

        function test_requestedRefreshOfAnEmptyGridShowsOneIndicator_data() {
            return [
                { tag: "pull to refresh", pullToRefresh: true, loadingIndicator: false, refreshing: true },
                { tag: "retry", pullToRefresh: false, loadingIndicator: true, refreshing: false }
            ]
        }

        function test_requestedRefreshOfAnEmptyGridShowsOneIndicator(data) {
            const { layout, store } = createLoadedLayout({ pullToRefreshEnabled: data.pullToRefresh })
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full
            layout.curatedRefreshRequested.connect(() => store.curatedCommunitiesLoading = true)
            const pill = errorPill(layout)
            waitForRendering(pill)

            mouseClick(pill, 30, pill.height / 2)

            compare(findChild(layout, "curatedCommunitiesLoadingIndicator").active, data.loadingIndicator)
            compare(findChild(layout, "curatedPullToRefresh").refreshing, data.refreshing)

            store.curatedCommunitiesLoading = false
            store.curatedCommunitiesLoading = true
            compare(findChild(layout, "curatedCommunitiesLoadingIndicator").active, true)
        }

        function test_loadingIndicatorIsDrawnAboveTheGrid() {
            const { layout, store } = createLoadedLayout()
            store.curatedCommunitiesLoading = true
            const indicator = findChild(layout, "curatedCommunitiesLoadingIndicator")
            const grid = findChild(layout, "curatedCommunitiesGrid")
            compare(indicator.active, true)
            compare(indicator.parent, grid.parent)
            verify(indicator.z > grid.z)
        }

        function test_refreshIndicatorIsNotShownWhenTheRequestedRefreshDoesNotStart() {
            const { layout, store } = createLoadedLayout()
            store.curatedCommunitiesRefreshError = Constants.CuratedCommunitiesRefreshError.Full
            const pill = errorPill(layout)
            waitForRendering(pill)

            mouseClick(pill, 30, pill.height / 2)
            compare(refreshSpy.count, 1)

            store.curatedCommunitiesModel.append(root.community)
            store.curatedCommunitiesLoading = true
            compare(findChild(layout, "curatedPullToRefresh").refreshing, false)
        }

        function test_loadingIsShownWhileTheGridIsEmpty() {
            const { indicator, store } = createLayout()
            tryCompare(indicator, "active", false)

            store.curatedCommunitiesLoading = true
            compare(indicator.active, true)

            store.curatedCommunitiesLoading = false
            compare(indicator.active, false)
        }

        function test_noCommunitiesFoundIsNotShownWhileLoading() {
            const { layout, indicator, store } = createLayout()
            tryCompare(indicator, "active", false)
            const noCommunities = findChild(layout, "noCommunitiesFoundText")
            verify(!!noCommunities)
            compare(noCommunities.visible, true)

            const grid = findChild(layout, "curatedCommunitiesGrid")
            const contentHeight = grid.contentHeight

            store.curatedCommunitiesLoading = true
            compare(noCommunities.opacity, 0)
            compare(grid.contentHeight, contentHeight)

            store.curatedCommunitiesLoading = false
            compare(noCommunities.opacity, 1)
            compare(grid.contentHeight, contentHeight)
        }

        function test_unknownCommunityIsShownAsASkeletonWhileLoading() {
            const { layout, indicator, store } = createLayout()
            tryCompare(indicator, "active", false)

            store.curatedCommunitiesLoading = true
            store.curatedCommunitiesModel.append(Object.assign({}, root.community, { available: false, name: "" }))

            const card = findChild(layout, "communityCard-")
            verify(!!card)
            compare(card.loaded, false)
            compare(indicator.active, false)
            compare(findChild(layout, "noCommunitiesFoundText").visible, false)
        }

        function test_loadingIsNotShownOverCards() {
            const { indicator, store } = createLayout()
            tryCompare(indicator, "active", false)

            store.curatedCommunitiesModel.append(root.community)
            store.curatedCommunitiesLoading = true
            compare(indicator.active, false)

            store.curatedCommunitiesModel.clear()
            compare(indicator.active, true)
        }
    }
}
