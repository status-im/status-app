// Real-instantiation scene for the SWAP modal. Loads the ACTUAL SwapModal QML
// tree + its real SwapModalAdaptor under an offscreen engine, and times:
//   - createObject of the whole modal (the structural instantiation cost, which
//     includes creating the 3 terminal token-selector picker models in `d`),
//   - open() -> `opened` (or a documented drain proxy when the offscreen enter
//     transition can't complete),
//   - the deferred handler setup() block (the "configure" cost), and
//   - a close + reopen (handler reuse).
//
// Unlike tst_SwapModal (which uses the storybook stub+mock module tree), this
// scene is SELF-CONTAINED: it subclasses the REAL store types inline and
// overrides only the members SwapModal reads, so it runs under the plain app
// import paths (ui/StatusQ/src, ui/imports, ui/app) with StatusQ linked, no
// storybook engine. The picker models are seeded to a synthetic catalog size N so
// the size-dependent create cost (and the KIND_SWAP_TO 3rd-picker share) is
// measured.
//
// OFFSCREEN CAVEAT: the terminal picker model here is a JS ListModel proxy for
// the real Nim producer (walletSectionTokenSelector is a context property absent
// offscreen); its per-row seed is a faithful shape/size proxy, not the Nim
// producer's exact cost. The SwapModal QML-tree structural cost is real.

import QtQuick
import QtQuick.Window
import QtQml.Models

import StatusQ.Core.Theme

import shared.stores
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Wallet.popups.swap

Window {
    id: root
    width: 600
    height: 1000
    visible: true

    // Synthetic catalog: N terminal token-selector rows per picker. Set by the
    // Nim driver before each createObject.
    property int catalogSize: 0
    // Suppress the KIND_SWAP_TO (kind 3) 3rd picker to attribute its share.
    property bool suppressSwapTo: false

    // Picker-model creation counters for the last run (attribution). kind1 = the
    // two source-chain pickers (pay + same-chain receive); kind3 = the eager
    // KIND_SWAP_TO destination picker.
    property int kind1Count: 0
    property int kind3Count: 0
    property int lastModelCount: 0

    // Per-create cached picker seeds (2 kind1 slots + 1 kind3 slot) so the
    // construction re-eval storm doesn't multiply the size-N seed.
    property var _preA: null
    property var _preB: null
    property var _preC: null
    property int _k1idx: 0

    property var _held: []

    // Build one terminal-selector-shaped ListModel with `n` rows. Mirrors the
    // roles the swap pickers/panels bind. Uses the BATCH append(array) form (one
    // call, not n calls) so the seed cost reflects a bulk build, not QML
    // ListModel's per-row append overhead.
    function buildSelectorRows(n) {
        const rows = new Array(n)
        for (let i = 0; i < n; i++) {
            rows[i] = {
                key: "grp_" + i,
                name: "Token Number " + i + " Wrapped Staked Governance Asset",
                symbol: "TKN" + i,
                logoUri: "https://raw.githubusercontent.com/status-im/assets/master/tokens/ethereum/0x" + i + "/logo.png",
                decimals: 18,
                cryptoPrice: 1.5,
                currentBalance: 5000000000.0,
                currencyBalance: 7500000000.0,
                sectionName: "",
                communityId: ""
            }
        }
        return rows
    }

    function buildSelectorModel(n) {
        const m = Qt.createQmlObject('import QtQuick; ListModel {}', root)
        if (n > 0)
            m.append(root.buildSelectorRows(n))
        return m
    }

    // ---- inline real-store subclasses -------------------------------------

    // Ids deliberately differ from the adaptor's property names (currencyStore,
    // networksStore, ...) so `currencyStore: theCurrencyStore` binds the Window's
    // store, not the adaptor's own same-named (null) property.
    CurrenciesStore { id: theCurrencyStore }   // real; safe offscreen (USD fallback)

    NetworksStore { id: theNetworksStore }     // real; activeNetworks empty offscreen

    WalletStores.SwapStore {
        id: theSwapStore
        // accounts is a readonly context binding in the base (undefined offscreen);
        // an empty account list is fine for instantiation. resetData/fetch are
        // no-ops here (no backend).
        function fetchSuggestedRoutes() {}
        function resetData() {}
        function authenticateAndTransfer() {}
        function reevaluateSwap() {}
    }

    WalletStores.TokensStore {
        id: theTokensStore
        networksStore: theNetworksStore

        // The linchpin override: hand out a size-N seeded terminal picker model
        // instead of delegating to the (absent) Nim producer. Suppress kind 3
        // when the scene asks, to attribute the eager 3rd picker on plain swaps.
        //
        // Production SwapModal creates exactly 3 pickers (2x kind 1: pay + same-
        // chain receive; 1x kind 3: KIND_SWAP_TO). But the picker properties are
        // `readonly property var ... createTokenSelectorModel(k)` whose binding
        // re-fires as `swapAdaptor` settles from null during construction, so this
        // override is CALLED many times. We cache per slot (2 kind1 slots +
        // 1 kind3 slot) so the size-N seed is paid exactly 3x IN the create window
        // (matching production), while re-eval calls reuse the cached model.
        function createTokenSelectorModel(kind) {
            if (kind === 3) {
                if (root.suppressSwapTo)
                    return { model: null, id: -1 }
                if (!root._preC) {
                    root._preC = root.buildSelectorModel(root.catalogSize)
                    root._held.push(root._preC)
                    root.kind3Count += 1
                }
                return { model: root._preC, id: 3 }
            }
            const slot = root._k1idx % 2
            root._k1idx += 1
            if (slot === 0) {
                if (!root._preA) {
                    root._preA = root.buildSelectorModel(root.catalogSize)
                    root._held.push(root._preA)
                    root.kind1Count += 1
                }
                return { model: root._preA, id: 1 }
            }
            if (!root._preB) {
                root._preB = root.buildSelectorModel(root.catalogSize)
                root._held.push(root._preB)
                root.kind1Count += 1
            }
            return { model: root._preB, id: 2 }
        }
        function releaseTokenSelectorModel(id) {}
        function isChainSupportedForSwapViaParaswap(chainId) { return true }
        function isChainSupportedForSwapViaLiFi(chainId) { return true }
        function buildGroupsForChain(chainId, keys) {}
        function buildGroupsForChainTo(chainId, keys) {}
    }

    WalletStores.WalletAssetsStore {
        id: theWalletAssetsStore
        walletTokensStore: theTokensStore
    }

    property SwapInputParamsForm swapFormData: SwapInputParamsForm {}

    Component {
        id: modalComp
        SwapModal {
            swapAdaptor: SwapModalAdaptor {
                currencyStore: theCurrencyStore
                walletAssetsStore: theWalletAssetsStore
                swapStore: theSwapStore
                networksStore: theNetworksStore
                swapFormData: root.swapFormData
                swapOutputData: SwapOutputData {}
            }
            swapInputParamsForm: root.swapFormData
            buyEnabled: true
        }
    }

    property var _modal: null

    // ---- scenario steps, driven one signal at a time by the Nim bench ------

    function doCreate(size, suppress) {
        root.catalogSize = size
        root.suppressSwapTo = suppress
        root.lastModelCount = 0
        root.kind1Count = 0
        root.kind3Count = 0
        root._preA = null; root._preB = null; root._preC = null; root._k1idx = 0
        root.swapFormData.resetFormData()
        if (root.swapFormData.selectedNetworkChainId === -1)
            root.swapFormData.selectedNetworkChainId = 1

        const t0 = bench.nowMs()
        const obj = modalComp.createObject(root)
        const t1 = bench.nowMs()
        if (!obj) {
            bench.reportCreate(-1, 0, modalComp.errorString())
            return
        }
        root._modal = obj
        obj.onOpened.connect(function() { bench.onModalOpened() })
        obj.onClosed.connect(function() { bench.onModalClosed() })
        bench.reportCreate(t1 - t0, root.kind1Count, root.kind3Count, "")
    }

    function doOpen() {
        if (!root._modal) { bench.onModalOpened(); return }
        root._modal.open()
    }

    function doClose() {
        if (!!root._modal) root._modal.close()
    }

    // The deferred handler setup(): the form-property assignments run via
    // Qt.callLater after onOpened in SwapModalHandler. Timed here.
    function doConfigure() {
        const f = root.swapFormData
        const t0 = bench.nowMs()
        f.fromGroupKey = Qt.binding(() => f.defaultFromGroupKey)
        f.toGroupKey = Qt.binding(() => f.defaultToGroupKey)
        f.selectedNetworkChainId = 1
        f.toNetworkChainId = 1
        f.defaultToGroupKey = f.getDefaultToGroupKey(f.selectedNetworkChainId)
        f.selectedSlippage = 0.5
        f.selectedAccountAddress = "0x7F47C2e18a4BBf5487E6fb082eC2D9Ab0E6d7240"
        f.fromTokenAmount = "0.001"
        const t1 = bench.nowMs()
        bench.reportConfigure(t1 - t0)
    }

    function doDestroy() {
        if (!!root._modal) { root._modal.destroy(); root._modal = null }
        for (let i = 0; i < root._held.length; i++) {
            if (!!root._held[i] && !!root._held[i].destroy) root._held[i].destroy()
        }
        root._held = []
    }

    Connections {
        target: bench
        function onRequestCreate(size, suppress) { root.doCreate(size, suppress) }
        function onRequestOpen() { root.doOpen() }
        function onRequestClose() { root.doClose() }
        function onRequestConfigure() { root.doConfigure() }
        function onRequestDestroy() { root.doDestroy() }
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
