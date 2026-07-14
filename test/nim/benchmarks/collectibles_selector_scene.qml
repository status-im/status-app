// RED scene: the real CollectiblesSelectionAdaptor proxy chain driving two REAL
// ListViews, the way the send modal's collectibles picker consumes it.
//
//   adaptor.model           -> grouped ListView (sections + per-group subitems
//                              count, mirroring SearchableCollectiblesPanel)
//   adaptor.filteredFlatModel-> flat ListView (key/chainId/name/balance/iconUrl,
//                              the shape deep-link resolution + delegates read)
//
// The universe is the user's REAL shape: a large GLOBAL collectibles set, but the
// probed account owns only ~30. Ownership is spread so three probe accounts each
// own ~30 and the bulk is owned by a whale account -- so an account switch keeps
// the OUTPUT at ~30 while the adaptor still re-filters O(GLOBAL) rows (the RED
// cost this bench exposes).
//
// The Nim harness (collectibles_selector_bench.nim) calls the scenario functions
// and reads the models' granular signal counts + delegate churn forwarded to the
// native `bench` object.

import QtQuick
import QtQuick.Window
import QtQml.Models

import AppLayouts.Wallet.adaptors

import QtModelsToolkit
import SortFilterProxyModel

import utils

Window {
    id: root
    width: 480
    height: 900
    visible: true // realize the offscreen surface so the ListViews create delegates

    readonly property var probeAccounts: ["acc_0", "acc_1", "acc_2"]
    readonly property string whaleAccount: "acc_whale"
    readonly property var chains: [1, 10, 42161, 8453, 56]

    property int ownedPerAccount: 30

    // ownerOf(i): first `ownedPerAccount*probeAccounts.length` items are split
    // among the probe accounts (~30 each); the rest belong to the whale. Keeps
    // every probe account's OWNED output ~constant while GLOBAL scales.
    function ownerOf(i) {
        const probed = root.probeAccounts.length * root.ownedPerAccount
        if (i < probed)
            return root.probeAccounts[Math.floor(i / root.ownedPerAccount)]
        return root.whaleAccount
    }

    function makeRow(i) {
        const isComm = (i % 10 === 0)          // ~10% community collectibles
        const comm = Math.floor(i / 300)       // a community spans 300 items
        const coll = Math.floor(i / 4)         // ~4 items per collection
        return {
            key: "col_" + i,
            chainId: root.chains[i % root.chains.length],
            contractAddress: "contract_" + coll,
            collectionUid: isComm ? ("ccoll_" + Math.floor(i / 40)) : ("coll_" + coll),
            collectionName: isComm ? ("CCollection " + Math.floor(i / 40)) : ("Collection " + coll),
            name: "Collectible " + i,
            tokenId: "" + i,
            mediaUrl: "",
            imageUrl: "",
            communityId: isComm ? ("community_" + comm) : "",
            communityName: isComm ? ("Community " + comm) : "",
            communityImage: "",
            communityPrivilegesLevel: Constants.TokenPrivilegesLevel.Community,
            soulbound: false,
            tokenType: 2,
            ownership: [{ accountAddress: root.ownerOf(i), balance: 1 }]
        }
    }

    // Raw source model, mutated by the append / balance-update scenarios.
    ListModel { id: collectiblesSrc }

    function fillSource(n) {
        const rows = []
        for (let i = 0; i < n; i++)
            rows.push(root.makeRow(i))
        collectiblesSrc.clear()
        collectiblesSrc.append(rows)
    }

    ListModel {
        id: netSrc
        Component.onCompleted: {
            const names = { 1: "Mainnet", 10: "Optimism", 42161: "Arbitrum", 8453: "Base", 56: "BSC" }
            const rows = []
            for (const c of root.chains)
                rows.push({ chainId: c, chainName: names[c], iconUrl: "network/ethereum" })
            append(rows)
        }
    }

    property string currentAccount: "acc_0"
    property var currentChainIds: []

    CollectiblesSelectionAdaptor {
        id: adaptor
        accountKey: root.currentAccount
        enabledChainIds: root.currentChainIds
        networksModel: netSrc
        // mirror SendModalHandler: soulbound items filtered out before the adaptor
        collectiblesModel: SortFilterProxyModel {
            sourceModel: collectiblesSrc
            filters: ValueFilter { roleName: "soulbound"; value: false }
        }
        filterCommunityOwnerAndMasterTokens: true
    }

    // --- grouped view: sections + per-group subitem count (panel shape) --------
    ListView {
        id: groupedView
        width: parent.width / 2
        height: parent.height
        model: adaptor.model
        cacheBuffer: 0
        delegate: Item {
            width: ListView.view.width
            height: 40
            property string _g: model.groupName
            property string _t: model.type
            property url _i: model.icon
            // realize the nested submodel object (ModelCount), like the panel's
            // `subitemsCount` -- without drilling into every subitem delegate
            property int _sc: model.subitems ? model.subitems.ModelCount.count : 0
            Component.onCompleted: bench.onDelegateCreated(0)
            Component.onDestruction: bench.onDelegateDestroyed(0)
        }
    }

    // --- flat view: the input-shaped rows deep-link resolution reads -----------
    ListView {
        id: flatView
        anchors.left: groupedView.right
        width: parent.width / 2
        height: parent.height
        model: adaptor.filteredFlatModel
        cacheBuffer: 0
        delegate: Item {
            width: ListView.view.width
            height: 40
            property string _k: model.key
            property int _c: model.chainId
            property string _n: model.name
            property int _b: model.balance
            property url _ic: model.iconUrl ?? ""
            Component.onCompleted: bench.onDelegateCreated(1)
            Component.onDestruction: bench.onDelegateDestroyed(1)
        }
    }

    Connections {
        target: adaptor.model
        function onDataChanged(tl, br, roles) { bench.onDataChanged(0, tl.row, br.row) }
        function onModelReset() { bench.onModelReset(0) }
        function onRowsInserted() { bench.onRowsInserted(0) }
        function onRowsRemoved() { bench.onRowsRemoved(0) }
    }

    Connections {
        target: adaptor.filteredFlatModel
        function onDataChanged(tl, br, roles) { bench.onDataChanged(1, tl.row, br.row) }
        function onModelReset() { bench.onModelReset(1) }
        function onRowsInserted() { bench.onRowsInserted(1) }
        function onRowsRemoved() { bench.onRowsRemoved(1) }
    }

    // --- scenario driver -------------------------------------------------------
    function outputCounts() {
        return [adaptor.filteredFlatModel.rowCount(), adaptor.model.rowCount()]
    }

    // 0 = build (fillSource with the requested size); others mutate in place.
    function runScenario(kind, arg) {
        switch (kind) {
        case 0: // initial build
            root.currentAccount = "acc_0"
            root.currentChainIds = []
            root.fillSource(arg)
            break
        case 1: // account switch
            root.currentAccount = (root.currentAccount === "acc_0") ? "acc_1" : "acc_0"
            break
        case 2: // enabledChainIds change
            root.currentChainIds = (root.currentChainIds.length === 0) ? [1, 10] : []
            break
        case 3: { // batch append of 50 rows owned by the current probe account
            const start = collectiblesSrc.count
            const rows = []
            for (let i = 0; i < 50; i++) {
                const r = root.makeRow(start + i)
                r.ownership = [{ accountAddress: root.currentAccount, balance: 1 }]
                rows.push(r)
            }
            collectiblesSrc.append(rows)
            break
        }
        case 4: { // single ownership balance update on a displayed collectible
            // bump the ERC-1155 balance of the first item owned by the current
            // account -> its SumAggregator recomputes and fans through the chain
            for (let i = 0; i < collectiblesSrc.count; i++) {
                const own = collectiblesSrc.get(i).ownership
                if (own.count > 0 && own.get(0).accountAddress === root.currentAccount) {
                    own.setProperty(0, "balance", own.get(0).balance + 1)
                    break
                }
            }
            break
        }
        }
    }

    function relayout() {
        groupedView.forceLayout()
        flatView.forceLayout()
        bench.reportCounts(adaptor.filteredFlatModel.rowCount(), adaptor.model.rowCount())
    }

    Connections {
        target: bench
        function onRequestScenario(kind, arg) { root.runScenario(kind, arg) }
        function onRequestRelayout() { root.relayout() }
    }

    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: bench.onStallTick()
    }

    Timer {
        interval: 50
        running: true
        repeat: false
        onTriggered: bench.onSceneReady()
    }
}
