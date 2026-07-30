// Benchmark scene: drives the full WalletAssetsStore model graph over synthetic
// source models and reports per-scenario measurements to the native `bench`
// object.
//
// Chain (mirrors ui/app/AppLayouts/Wallet/stores/WalletAssetsStore.qml then
// ui/imports/shared/views/AssetsView.qml, terminal roles/sorters verbatim):
//
//   tokenGroups ─┐
//                ├─ LeftJoin(joinRole "communityId") = tokenGroupsJoined ─┐
//   communities ─┘                                                        │
//                                                          leftAssets ─────┤
//                                                                          ├─ LeftJoin(joinRole "key") = assets
//                                                                          │
//   assets ── SFPM(visible filter) ── SFPM(FastExpressionRoles + RoleSorters, dynamicSort) ── ListView
//
// Why two real LeftJoinModels:
// a right-model cell change makes LeftJoinModel emit a WHOLE-model dataChanged
// (leftjoinmodel.cpp:285), the ×N amplification the terminal model
// removes. tokenGroups feeds the inner join, whose output is the RIGHT model of
// the outer join, so market-detail / balance edits on tokenGroups exercise that
// whole-model emission exactly as production does.
//
// LeftJoinModel::initializeIfReady bails while either source reports empty
// roleNames (a QML ListModel is role-less until its first row), so every source
// carries a seed ListElement declaring its roles up front; the join is live
// before the universe is built and stays live across clear()/append().
//
// Reduction vs production: ManageTokensController's ObjectProxyModel + settings
// persistence is the SFPM(visible) filter (same propagation depth, no I/O).

import QtQuick
import QtQuick.Window

import StatusQ
import SortFilterProxyModel
import QtModelsToolkit

Window {
    id: root
    width: 420
    height: 900
    visible: true // realize the offscreen surface so the ListView creates delegates

    // --- dynamic sort control (mirrors AssetsView's RoleSorter binding) ---
    property string sortRole: "marketBalance"
    property int sortOrder: Qt.DescendingOrder

    // --- signal + delegate churn counters (reset per scenario) ---
    property int cDataChanged: 0
    property int cDataChangedRows: 0   // summed row-span of terminal dataChanged (amplification magnitude)
    property int cLayoutChanged: 0
    property int cReset: 0
    property int cInserted: 0
    property int cRemoved: 0
    property int cDelegatesCreated: 0
    property int cDelegatesDestroyed: 0

    function resetCounters() {
        cDataChanged = 0; cDataChangedRows = 0; cLayoutChanged = 0; cReset = 0
        cInserted = 0; cRemoved = 0
        cDelegatesCreated = 0; cDelegatesDestroyed = 0
    }

    // ---- source models (each seeded so its roleNames are non-empty at load) ----
    // Grouped account assets (outer-join LEFT): the row set + per-account fields.
    ListModel {
        id: leftAssets
        ListElement {
            key: "seed"; visible: false; position: 0; canBeHidden: true; error: ""
        }
    }
    // Token groups incl. market details (inner-join LEFT, i.e. outer-join RIGHT
    // once joined with communities): balance + marketPrice live here so both the
    // market-detail and balance edits flow through the amplifying right side.
    ListModel {
        id: tokenGroups
        ListElement {
            key: "seed"; name: "seed"; symbol: "seed"; logoUri: ""
            balance: 0.0; balanceText: "0"; balanceLoading: false
            marketPrice: 0.0; marketChangePct24hour: 0.0
            marketDetailsAvailable: false; marketDetailsLoading: false
            communityId: ""
        }
    }
    // Communities (inner-join RIGHT).
    ListModel {
        id: communities
        ListElement {
            communityId: ""; communityName: ""; communityImage: ""; communityDescription: ""
        }
    }

    LeftJoinModel {
        id: tokenGroupsJoined
        leftModel: tokenGroups
        rightModel: communities
        joinRole: "communityId"
    }

    LeftJoinModel {
        id: assets
        objectName: "groupedAccountAssetsModel"
        leftModel: leftAssets
        rightModel: tokenGroupsJoined
        joinRole: "key"
    }

    SortFilterProxyModel {
        id: visibleSfpm
        sourceModel: assets
        filters: ValueFilter { roleName: "visible"; value: true }
    }

    SortFilterProxyModel {
        id: terminal
        sourceModel: visibleSfpm

        proxyRoles: [
            FastExpressionRole {
                name: "isCommunity"
                expression: !!model.communityId ? "community" : ""
                expectedRoles: ["communityId"]
            },
            FastExpressionRole {
                name: "marketBalance"
                expression: model.balance * model.marketPrice
                expectedRoles: ["balance", "marketPrice"]
            },
            FastExpressionRole {
                name: "change1DayFiat"
                expression: model.marketBalance * (1 - (1 / (model.marketChangePct24hour / 100 + 1)))
                expectedRoles: ["marketBalance", "marketChangePct24hour"]
            }
        ]

        sorters: [
            RoleSorter { roleName: "isCommunity" },
            RoleSorter { roleName: root.sortRole; sortOrder: root.sortOrder }
        ]
    }

    Connections {
        target: terminal
        function onDataChanged(topLeft, bottomRight, roles) {
            root.cDataChanged++
            root.cDataChangedRows += (bottomRight.row - topLeft.row + 1)
        }
        function onLayoutChanged() { root.cLayoutChanged++ }
        function onModelReset() { root.cReset++ }
        function onRowsInserted() { root.cInserted++ }
        function onRowsRemoved() { root.cRemoved++ }
    }

    ListView {
        id: listView
        anchors.fill: parent
        model: terminal
        cacheBuffer: 0
        delegate: Rectangle {
            width: ListView.view.width
            height: 44
            // read the same roles AssetsView's TokenDelegate binds
            property string _k: model.key
            property real _mb: model.marketBalance
            property real _c1d: model.change1DayFiat
            property string _n: model.name
            Component.onCompleted: root.cDelegatesCreated++
            Component.onDestruction: root.cDelegatesDestroyed++
        }
    }

    // ---- universe construction ----
    function makeAssetRow(i, numChains) {
        const chain = i % numChains
        return {
            key: "tok_" + i + "_c" + chain,
            visible: true,
            position: i,
            canBeHidden: true,
            error: ""
        }
    }

    function makeGroupRow(i, numChains) {
        const chain = i % numChains
        return {
            key: "tok_" + i + "_c" + chain,
            name: "Token " + i,
            symbol: "T" + i,
            logoUri: "",
            balance: (i % 1000) + 1.5,
            balanceText: String((i % 1000) + 1.5),
            balanceLoading: false,
            marketPrice: 1.0 + (i % 500) * 0.01,
            marketChangePct24hour: ((i % 40) - 20) * 0.5,
            marketDetailsAvailable: true,
            marketDetailsLoading: false,
            communityId: ""
        }
    }

    function buildUniverse(numTokens, numChains) {
        // Detach the joins, fully populate the sources, then reattach so the
        // rebuild costs one O(N) initialization each (this is the reviewer's
        // "pre-populate the sources before assigning them to the LeftJoinModel"
        // rule): while attached, every append to a right-joined source fires a
        // whole-model dataChanged, so an incremental build is O(N^2).
        assets.leftModel = null
        assets.rightModel = null
        tokenGroupsJoined.leftModel = null
        tokenGroupsJoined.rightModel = null

        // communities is never cleared: emptying it would drop its roleNames and
        // de-initialize the inner join. Its single seed row (communityId "")
        // carries the roles and matches the no-community tokens harmlessly.
        leftAssets.clear()
        tokenGroups.clear()
        for (let i = 0; i < numTokens; i++) {
            tokenGroups.append(makeGroupRow(i, numChains))
            leftAssets.append(makeAssetRow(i, numChains))
        }

        // Reattach inner join first so its roleNames exist before the outer join
        // takes it as a right model.
        tokenGroupsJoined.leftModel = tokenGroups
        tokenGroupsJoined.rightModel = communities
        assets.leftModel = leftAssets
        assets.rightModel = tokenGroupsJoined
        listView.forceLayout()
    }

    // ---- update classes ----
    // Market details live on the right-joined tokenGroups model -> a single-cell
    // edit fans out to a whole-model dataChanged through the outer join.
    function doMarketDetailChange() {
        const i = Math.floor(tokenGroups.count / 2)
        tokenGroups.setProperty(i, "marketPrice", tokenGroups.get(i).marketPrice + 1.0)
        tokenGroups.setProperty(i, "marketChangePct24hour", tokenGroups.get(i).marketChangePct24hour + 0.25)
    }

    function doBalanceUpdate() {
        const i = Math.floor(tokenGroups.count / 2)
        const cur = tokenGroups.get(i).balance
        tokenGroups.setProperty(i, "balance", cur + 1.0)
        tokenGroups.setProperty(i, "balanceText", String(cur + 1.0))
    }

    // Every token's market detail changes in one tick, reshuffling the
    // marketBalance ranking wholesale (global re-rank worst case). Each
    // setProperty on the right-joined tokenGroups fans out to a whole-model
    // dataChanged, so this is O(N^2) row-touches through the proxy chain.
    function doAllPricesChange() {
        const n = tokenGroups.count
        for (let i = 0; i < n; i++) {
            tokenGroups.setProperty(i, "marketPrice", ((n - i) % 500) * 0.02 + 0.5)
            tokenGroups.setProperty(i, "marketChangePct24hour", tokenGroups.get(i).marketChangePct24hour + 0.5)
        }
    }

    // Add/remove operate on the outer-join LEFT (the row-set driver); a matching
    // group row keeps marketBalance defined, mirroring "new asset + its group".
    function doAddToken() {
        const i = leftAssets.count
        const grp = makeGroupRow(i, 5)
        grp.key = "added_" + i
        const asset = makeAssetRow(i, 5)
        asset.key = "added_" + i
        tokenGroups.append(grp)
        leftAssets.append(asset)
    }

    function doRemoveToken() {
        leftAssets.remove(Math.floor(leftAssets.count / 2))
    }

    // Reorder the source rows without changing the set (distinct from sort_flip,
    // which flips the terminal sorter). Exercises left-model move/layoutChanged.
    function doSourceReorder() {
        const n = leftAssets.count
        if (n < 4)
            return
        leftAssets.move(0, n - 1, 1)
        leftAssets.move(Math.floor(n / 3), Math.floor((2 * n) / 3), 1)
    }

    function doFullRefresh(numTokens, numChains) {
        buildUniverse(numTokens, numChains)
    }

    function doSortFlip() {
        root.sortOrder = (root.sortOrder === Qt.DescendingOrder)
            ? Qt.AscendingOrder : Qt.DescendingOrder
    }

    function measure(size, chains, scenario, fn) {
        resetCounters()
        const t0 = bench.nowNs()
        fn()
        listView.forceLayout()
        bench.pump() // flush deferred SFPM invalidation + delegate realization
        const t1 = bench.nowNs()
        bench.record(size, scenario, (t1 - t0) / 1000000.0,
            cDataChanged, cDataChangedRows, cLayoutChanged, cReset, cInserted, cRemoved,
            cDelegatesCreated, cDelegatesDestroyed)
    }

    function runSize(size, chains) {
        buildUniverse(size, chains)
        bench.pump() // settle the initial load before measuring
        measure(size, chains, "market_detail_change", () => doMarketDetailChange())
        measure(size, chains, "balance_update", () => doBalanceUpdate())
        measure(size, chains, "add_token", () => doAddToken())
        measure(size, chains, "remove_token", () => doRemoveToken())
        measure(size, chains, "source_reorder", () => doSourceReorder())
        measure(size, chains, "all_prices_change", () => doAllPricesChange())
        measure(size, chains, "sort_flip", () => doSortFlip())
        measure(size, chains, "full_refresh", () => doFullRefresh(size, chains))
    }

    // Run after the window is exposed and the first frame is rendered, so the
    // ListView realizes delegates and the proxy chain is live (running in
    // Component.onCompleted fires during load, before the surface exists).
    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: {
            const chains = 5
            const sizes = benchQuick ? [100] : [100, 1000, 5000]
            for (const size of sizes)
                runSize(size, chains)
            bench.done()
        }
    }
}
