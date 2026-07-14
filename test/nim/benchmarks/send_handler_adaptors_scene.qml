// Real-adaptor scene for the send modal's HANDLER-side cost. SendModalHandler
// eagerly builds three adaptors when the modal opens; only the recipient/accounts
// ones feed the initially-visible ASSETS tab, while CollectiblesSelectionAdaptor
// (a LeftJoin + SFPM + nested per-group ObjectProxyModel chain over the full
// cross-chain collectibles model) is pure waste in the open window.
//
// This scene instantiates each adaptor with REALISTIC stub inputs and times:
//  - createObject wall (the synchronous structural build the open pays),
//  - the GUI-thread block via a 16ms stall monitor,
//  - time-until-populated ("settle"): keep pumping events until the adaptor's
//    output row counts stop changing (ObjectProxyModel chains build per-row and
//    per-group submodels which may land after createObject returns).
//
// Collectibles are measured at 200 / 1000 / 3000 items across 5 chains, ~40%
// community collectibles (exercises the expensive nested community->collection
// regrouping), all owned by the probed account so nothing is filtered out.
//
// NOTE: stub-model ids carry a `Src` suffix so they never collide with the
// adaptor property names they feed (e.g. `networksModel: netSrc`); a matching
// name would self-reference the adaptor's own (still-undefined) property.

import QtQuick
import QtQml.Models

import StatusQ.Core.Theme

import AppLayouts.Wallet.adaptors

import QtModelsToolkit
import SortFilterProxyModel

import utils

Item {
    id: root
    width: 400
    height: 400
    visible: true

    readonly property string probedAccount: "acc_0"
    readonly property var chains: [1, 10, 42161, 8453, 56]

    // --- collectibles source models (raw, prebuilt; not part of measured cost) ---
    function genCollectibles(model, n) {
        const rows = []
        for (let i = 0; i < n; i++) {
            const isComm = (i % 5 < 2) // ~40% community collectibles
            const g = Math.floor(i / 8) // ~8 items per collection
            const comm = Math.floor(i / 40) // community groups
            rows.push({
                key: "col_" + i,
                symbol: "C" + i,
                chainId: root.chains[i % root.chains.length],
                contractAddress: "contract_" + g,
                collectionUid: "collection_" + g,
                collectionName: "Collection " + g,
                name: "Collectible " + i,
                mediaUrl: "",
                imageUrl: "",
                communityId: isComm ? ("community_" + comm) : "",
                communityName: isComm ? ("Community " + comm) : "",
                communityImage: "",
                communityPrivilegesLevel: Constants.TokenPrivilegesLevel.Community,
                soulbound: false,
                tokenType: 2,
                ownership: [{ accountAddress: root.probedAccount, balance: 1 }]
            })
        }
        model.append(rows)
    }

    ListModel { id: collectibles200Src; Component.onCompleted: root.genCollectibles(this, 200) }
    ListModel { id: collectibles1000Src; Component.onCompleted: root.genCollectibles(this, 1000) }
    ListModel { id: collectibles3000Src; Component.onCompleted: root.genCollectibles(this, 3000) }

    // --- networks (LeftJoin right side) ---
    ListModel {
        id: netSrc
        Component.onCompleted: {
            const names = { 1: "Mainnet", 10: "Optimism", 42161: "Arbitrum", 8453: "Base", 56: "BSC" }
            const rows = []
            for (const c of root.chains)
                rows.push({ chainId: c, chainName: names[c], iconUrl: "network/ethereum",
                            chainColor: "#627EEA", shortName: names[c], layer: (c === 1 ? 1 : 2) })
            append(rows)
        }
    }

    // --- accounts / assets / recipients stubs (for the other two adaptors) ---
    ListModel {
        id: accountsSrc
        Component.onCompleted: {
            const rows = []
            for (let i = 0; i < 15; i++)
                rows.push({ address: "acc_" + i, name: "Account " + i, color: "#C78F67",
                            colorId: "camel", emoji: "🔑", ens: "acc" + i + ".eth",
                            canSend: true, position: i, walletType: "key",
                            currencyBalance: { amount: 1000 - i * 10, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false },
                            migratedToColdWallet: false })
            append(rows)
        }
    }

    ListModel {
        id: assetsSrc
        Component.onCompleted: {
            const rows = []
            for (let t = 0; t < 50; t++) {
                const balances = []
                for (const c of root.chains)
                    balances.push({ chainId: c, account: "acc_0", balance: "1000", rawBalance: "1000000000000000000",
                                    iconUrl: "network/ethereum" })
                rows.push({ key: "tok_" + t, tokensKey: "tok_" + t, symbol: "TK" + t, name: "Token " + t,
                            decimals: 18, communityId: "",
                            marketDetails: { currencyPrice: { amount: 1.0, symbol: "USD" } },
                            currencyBalance: { amount: 100, symbol: "USD", displayDecimals: 2, stripTrailingZeroes: false },
                            balances: balances })
            }
            append(rows)
        }
    }

    ListModel {
        id: tokenGroupsSrc
        Component.onCompleted: {
            const rows = []
            for (let t = 0; t < 50; t++)
                rows.push({ key: "tok_" + t, symbol: "TK" + t, name: "Token " + t, decimals: 18 })
            append(rows)
        }
    }

    ListModel {
        id: savedSrc
        Component.onCompleted: {
            const rows = []
            for (let i = 0; i < 50; i++)
                rows.push({ address: "saved_" + i, name: "Saved " + i, colorId: "army", emoji: "🚗",
                            ens: "saved" + i + ".eth" })
            append(rows)
        }
    }

    ListModel {
        id: recentsSrc
        Component.onCompleted: {
            const rows = []
            for (let i = 0; i < 100; i++)
                rows.push({ activityEntry: { sender: "acc_0", recipient: "recent_" + i,
                                             txType: Constants.TransactionType.Send } })
            append(rows)
        }
    }

    function fnFmt(a, s, o) { return "" }
    function fnFmtBig(a, s, d) { return "" }

    // --- adaptor catalog ---------------------------------------------------
    Component {
        id: collectiblesComp
        CollectiblesSelectionAdaptor {
            required property var source
            accountKey: root.probedAccount
            enabledChainIds: [] // all chains -> full pipeline (per-row build is chain-independent)
            networksModel: netSrc
            // mirror SendModalHandler: soulbound items filtered out before the adaptor
            collectiblesModel: SortFilterProxyModel {
                sourceModel: source
                filters: ValueFilter { roleName: "soulbound"; value: false }
            }
            filterCommunityOwnerAndMasterTokens: true
        }
    }

    Component {
        id: accountsComp
        WalletAccountsSelectorAdaptor {
            accounts: accountsSrc
            assetsModel: assetsSrc
            tokenGroupsModel: tokenGroupsSrc
            filteredFlatNetworksModel: netSrc
            selectedGroupKey: "tok_0"
            selectedNetworkChainId: 1
            fnFormatCurrencyAmountFromBigInt: root.fnFmtBig
        }
    }

    Component {
        id: recipientsComp
        RecipientViewAdaptor {
            savedAddressesModel: savedSrc
            accountsModel: accountsSrc
            recentRecipientsModel: recentsSrc
            selectedRecipientType: 0
            searchPattern: ""
            selectedSenderAddress: ""
        }
    }

    // Mirrors the GREEN fix in SendModalHandler: the collectibles adaptor lives
    // behind a Loader gated on `collectiblesNeeded`. Inactive at open (assets tab),
    // activated when the user first opens the collectibles tab.
    Component {
        id: deferredCollectiblesComp
        Loader {
            property var source
            active: false
            sourceComponent: CollectiblesSelectionAdaptor {
                accountKey: root.probedAccount
                enabledChainIds: []
                networksModel: netSrc
                collectiblesModel: SortFilterProxyModel {
                    sourceModel: source
                    filters: ValueFilter { roleName: "soulbound"; value: false }
                }
                filterCommunityOwnerAndMasterTokens: true
            }
        }
    }

    function createFor(kind) {
        switch (kind) {
        case 0: return collectiblesComp.createObject(root, { source: collectibles200Src })
        case 1: return collectiblesComp.createObject(root, { source: collectibles1000Src })
        case 2: return collectiblesComp.createObject(root, { source: collectibles3000Src })
        case 3: return accountsComp.createObject(root)
        case 4: return recipientsComp.createObject(root)
        }
        return null
    }

    // output row counts used for settle detection (sum must stabilize)
    function outputCounts(kind, obj) {
        switch (kind) {
        case 0: case 1: case 2:
            return [obj.filteredFlatModel.rowCount(), obj.model.rowCount()]
        case 3: return [obj.processedWalletAccounts.rowCount(), 0]
        case 4: return [obj.recipientsModel.rowCount(), 0]
        case 5: return obj.item ? [obj.item.filteredFlatModel.rowCount(), obj.item.model.rowCount()] : [0, 0]
        }
        return [0, 0]
    }

    property var _held: []

    // settle state
    property var _settleObj: null
    property int _settleKind: -1
    property real _settleStart: 0
    property int _settleLastSum: -1
    property int _settleStable: 0

    function runKind(kind) {
        // Deferred collectibles: createObject is the OPEN-window cost (Loader
        // inactive -> adaptor not built); the settle timing then measures the
        // FIRST-TAB-OPEN cost when the gate flips active.
        if (kind === 5) {
            const dt0 = bench.nowMs()
            const loader = deferredCollectiblesComp.createObject(root, { source: collectibles3000Src })
            const dt1 = bench.nowMs()
            if (!loader) { bench.reportInstantiation(kind, -1, "no-comp"); bench.reportSettle(kind, 0, 0, 0); return }
            _held.push(loader)
            bench.reportInstantiation(kind, dt1 - dt0, "") // open-window cost (~0)

            _settleObj = loader
            _settleKind = kind
            _settleStart = bench.nowMs()
            _settleLastSum = -1
            _settleStable = 0
            loader.active = true // user opens the collectibles tab
            settleTimer.restart()
            return
        }

        const t0 = bench.nowMs()
        const obj = createFor(kind)
        const t1 = bench.nowMs()
        if (!obj) { bench.reportInstantiation(kind, -1, "no-comp"); bench.reportSettle(kind, 0, 0, 0); return }
        _held.push(obj)
        bench.reportInstantiation(kind, t1 - t0, "")

        // begin settle polling
        _settleObj = obj
        _settleKind = kind
        _settleStart = t1
        _settleLastSum = -1
        _settleStable = 0
        settleTimer.restart()
    }

    Timer {
        id: settleTimer
        interval: 1
        repeat: true
        onTriggered: {
            const c = root.outputCounts(root._settleKind, root._settleObj)
            const sum = c[0] + c[1]
            if (sum === root._settleLastSum) {
                root._settleStable++
                if (root._settleStable >= 8 || (bench.nowMs() - root._settleStart) > 6000) {
                    settleTimer.stop()
                    bench.reportSettle(root._settleKind, bench.nowMs() - root._settleStart, c[0], c[1])
                }
            } else {
                root._settleLastSum = sum
                root._settleStable = 0
            }
        }
    }

    Connections {
        target: bench
        function onRequestKind(kind) { root.runKind(kind) }
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
