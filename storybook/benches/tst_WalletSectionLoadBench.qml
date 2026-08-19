import QtQuick
import QtTest

import StatusQ.Core.Theme

import shared.stores as SharedStores

import AppLayouts.stores as AppStores
import AppLayouts.Communities.stores as CommunityStores
import AppLayouts.Wallet.stores as WalletStores

import mainui.sectionLoaders

import Mocks
import Models
import StorybookMocks

// Load bench for the wallet section surface (issues/0001).
//
// Records the load staircase (time-to-skeleton / time-to-ready / time-to-content)
// from `WalletLoader.active = true` against the whale profile, runs a 1ms stall
// probe through the window, counts what the section instantiates, and appends a
// row to the checked-in baselines TSV.
//
// Measured caveat on the top rung: on this surface the two nested async loaders
// are already Ready when WalletLoader reports Ready - they complete inside the
// outer incubation - so time-to-content lands 0.7ms after time-to-ready and
// certifies only that the loaders reported Ready. Half of what the section
// builds (and every assets row) arrives on the layout pass that follows, so the
// window runs on to the settle point: the first realised assets row plus a
// stable object count. `t_first_asset_row_ms` and the settled counts are what
// carry the "no grey tiles left" meaning here.
//
// Timings and the max stall are recorded only; the instantiation counts and the
// stall count are gated. All numbers are HOST units - the x10 low-end-Android
// convention is applied by whoever reads them, never here.
Item {
    id: root

    // Fixed section geometry: the delegate counts are gated, and a list view
    // fills as many delegates as its height allows.
    width: 1440
    height: 900

    // Whale profile: the mock's own defaults, deliberately not overridden.
    WalletSectionMock { id: walletMock }

    AppStores.RootStore { id: appRootStoreMock }
    AppStores.ContactsStore { id: contactsStoreMock }
    AppStores.FeatureFlagsStore {
        id: featureFlagsStoreMock
        swapEnabled: true
        buyEnabled: true
        keycardEnabled: true
    }
    SharedStores.RootStore { id: sharedRootStoreMock }
    SharedStores.NetworkConnectionStore { id: networkConnectionStoreMock }
    SharedStores.NetworksStore { id: networksStoreMock }
    CommunityStores.CommunitiesStore { id: communitiesStoreMock }
    WalletSectionTransactionStoreMock { id: transactionStoreMock }

    WalletLoadBenchProbe { id: probe }

    Item {
        id: popupParent
        anchors.fill: parent
    }

    WalletSectionPopupsMock {
        id: popupsMock

        popupParent: popupParent

        rootStore: appRootStoreMock
        featureFlagsStore: featureFlagsStoreMock
        contactsStore: contactsStoreMock
        sharedRootStore: sharedRootStoreMock
        networksStore: networksStoreMock
        networkConnectionStore: networkConnectionStoreMock
        transactionStore: transactionStoreMock
    }

    Item {
        visible: false
        Loader { id: dappsServiceLoaderMock; active: false }
        Loader { id: emojiPopupLoaderMock; active: false }
    }

    // Synchronous on purpose: activating it is the start of the measurement
    // window, so nothing of the section may be built before that assignment.
    Loader {
        id: harness

        anchors.fill: parent
        active: false

        sourceComponent: WalletLoader {
            id: walletLoader

            active: true
            appMainVisible: true

            rootStore: appRootStoreMock
            contactsStore: contactsStoreMock
            featureFlagsStore: featureFlagsStoreMock
            sharedRootStore: sharedRootStoreMock
            networkConnectionStore: networkConnectionStoreMock
            networksStore: networksStoreMock
            communitiesStore: communitiesStoreMock
            transactionStore: transactionStoreMock

            popupHandler: popupsMock.popupHandler
            dappsServiceLoader: dappsServiceLoaderMock
            emojiPopupLoader: emojiPopupLoaderMock

            onStatusChanged: {
                if (status !== Loader.Ready)
                    return
                probe.stamp("t_ready")
                // `harness.item` is not assigned yet when the section loads
                // synchronously, so the section is handed over by id.
                d.watchNestedLoaders(walletLoader)
            }
        }
    }

    // The nested loaders are found once the section is Ready; their status
    // changes are what the time-to-content stop line watches.
    Connections {
        target: d.accountsListLoader
        function onStatusChanged() { d.stampContentWhenReady() }
    }

    Connections {
        target: d.mainViewLoader
        function onStatusChanged() { d.stampContentWhenReady() }
    }

    QtObject {
        id: d

        property var section: null
        property var accountsListLoader: null
        property var mainViewLoader: null
        property var accountsListLoaders: []
        property var mainViewLoaders: []

        property int objectsTotal: -1
        property int accountDelegates: -1
        property int assetDelegates: -1
        property int loadingAssetDelegates: -1

        property real firstAssetRowMs: -1
        property int objectsSettled: -1
        property int assetDelegatesSettled: -1

        // The section's panels have no visual parent until the chrome's swap
        // gates promote them, so they are reached through WalletLayout's own
        // panel properties rather than by walking the loader's item tree.
        function asyncLoadersIn(subtreeRoot) {
            if (!subtreeRoot)
                return []
            return probe.findAllByTypePrefix(subtreeRoot, "QQuickLoader")
                        .filter(loader => loader.asynchronous)
        }

        function watchNestedLoaders(section) {
            d.section = section
            const layout = section.item
            d.accountsListLoaders = d.asyncLoadersIn(layout.leftPanel)
            d.mainViewLoaders = d.asyncLoadersIn(layout.centerPanel)

            d.accountsListLoader = d.accountsListLoaders.length === 1
                                 ? d.accountsListLoaders[0] : null
            d.mainViewLoader = d.mainViewLoaders.length === 1
                             ? d.mainViewLoaders[0] : null
            d.stampContentWhenReady()
        }

        function stampContentWhenReady() {
            if (probe.hasStamp("t_content"))
                return
            if (!d.accountsListLoader || !d.mainViewLoader)
                return
            if (d.accountsListLoader.status !== Loader.Ready
                    || d.mainViewLoader.status !== Loader.Ready)
                return

            probe.stamp("t_content")
            d.takeInstantiationCounts()
        }

        // Taken at the t_content stamp: what the section had built by the time
        // it declared its loaders Ready.
        function takeInstantiationCounts() {
            const section = d.section
            d.objectsTotal = probe.countObjects(section)
            d.accountDelegates = probe.countByObjectNamePrefix(section, "walletAccountListItem")
            d.assetDelegates = probe.countByObjectNamePrefix(section, "AssetView_TokenListItem_")
            d.loadingAssetDelegates = probe.countByObjectNamePrefix(
                        section, "AssetView_LoadingTokenDelegate_")
        }

        function assetRows() {
            return probe.countByObjectNamePrefix(d.section, "AssetView_TokenListItem_")
        }

        // Runs the loop on in 1ms slices to the first realised assets row, then
        // drains until the object count holds still over two 50ms samples. Both
        // stop conditions are observed, never waited out by a fixed delay.
        function settle(timeoutMs) {
            const deadline = probe.elapsedMs + timeoutMs

            while (d.assetRows() === 0 && probe.elapsedMs < deadline)
                probe.waitForStamp("never-stamped", 1)
            d.firstAssetRowMs = probe.elapsedMs

            let previous = -1
            let current = probe.countObjects(d.section)
            while (current !== previous && probe.elapsedMs < deadline) {
                previous = current
                probe.waitForStamp("never-stamped", 50)
                current = probe.countObjects(d.section)
            }

            probe.end()
            d.objectsSettled = current
            d.assetDelegatesSettled = d.assetRows()
        }
    }

    TestCase {
        name: "WalletSectionLoadBench"
        when: windowShown

        readonly property string tsvPath:
            probe.sourceDir + "/benches/baselines/wallet-section-load.tsv"

        readonly property var tsvHeader: [
            "utc_time", "profile",
            "t_skeleton_ms", "t_ready_ms", "t_content_ms",
            "t_first_asset_row_ms",
            "stalls_over_4ms", "max_stall_ms", "probe_ticks",
            "objects_total", "account_delegates", "asset_delegates",
            "loading_asset_delegates",
            "objects_settled", "asset_delegates_settled"
        ]

        // Gates, all measured on this harness and stable across runs.
        //
        // The two zeros are the load-staircase invariant, not an absence of
        // data: at time-to-content the assets list must not have produced a
        // single row yet - the accounts list is the only list the section
        // builds before it calls itself loaded.
        readonly property int expectedAccountDelegates: 8
        readonly property int expectedAssetDelegates: 0
        readonly property int expectedLoadingAssetDelegates: 0
        readonly property int expectedObjectsTotal: 4602
        readonly property int objectsTotalTolerance: 0

        // The settled counts are the ones that see the whole section: the
        // layout pass after the loaders report Ready more than doubles the
        // object count and is where every assets row is built.
        readonly property int expectedObjectsSettled: 9569
        readonly property int expectedAssetDelegatesSettled: 26

        // A ratchet on today's measured count, not the 0 the host budget would
        // want: the section blocks the GUI thread for ~345ms of its ~560ms
        // load, so 4ms-clean is several optimisations away. Lower this whenever
        // a fix lowers the count.
        readonly property int maxStallsOver4ms: 16

        function initTestCase() {
            WalletStores.RootStore.palette = Theme.palette
        }

        function cleanupTestCase() {
            harness.active = false
            walletMock.uninstall()
        }

        function test_walletSectionLoadStaircase() {
            walletMock.install()

            probe.begin()
            harness.active = true
            // Everything the loader builds synchronously - the section chrome
            // and both skeleton panels - exists by the time the assignment
            // returns; that is the time-to-skeleton stop line.
            probe.stamp("t_skeleton")

            const skeleton = probe.findByTypePrefix(harness.item, "WalletAccountsSkeleton")
            verify(!!skeleton, "time-to-skeleton: no WalletAccountsSkeleton in the section chrome")
            verify(skeleton.visible, "time-to-skeleton: the accounts skeleton is not visible")

            verify(probe.waitForStamp("t_ready", 60000),
                   "the wallet section never reached Loader.Ready")

            verify(!!d.accountsListLoader,
                   "time-to-content: could not locate the accounts list loader - the "
                   + "left panel holds %1 asynchronous Loaders, expected exactly one"
                   .arg(d.accountsListLoaders.length))
            verify(!!d.mainViewLoader,
                   "time-to-content: could not locate the main view loader - the "
                   + "center panel holds %1 asynchronous Loaders, expected exactly one"
                   .arg(d.mainViewLoaders.length))

            verify(probe.waitForStamp("t_content", 60000),
                   "time-to-content: the accounts list and the main view never both "
                   + "reached Loader.Ready")

            d.settle(60000)
            verify(d.firstAssetRowMs < 60000,
                   "the assets list never realised a row after time-to-content")

            printStaircase()
            recordRow()

            countGate("account_delegates", d.accountDelegates, expectedAccountDelegates)
            countGate("asset_delegates", d.assetDelegates, expectedAssetDelegates)
            countGate("loading_asset_delegates", d.loadingAssetDelegates,
                      expectedLoadingAssetDelegates)
            countGate("objects_total", d.objectsTotal, expectedObjectsTotal)
            countGate("objects_settled", d.objectsSettled, expectedObjectsSettled)
            countGate("asset_delegates_settled", d.assetDelegatesSettled,
                      expectedAssetDelegatesSettled)

            verify(probe.stallCount <= maxStallsOver4ms,
                   "GATE `stalls_over_4ms` = %1, baseline allows %2 (%3) - host ms, 1ms "
                   .arg(probe.stallCount).arg(maxStallsOver4ms).arg(signed(probe.stallCount - maxStallsOver4ms))
                   + "probe, window is the whole load up to the settle point")
        }

        // One line carrying metric, both numbers and the delta: a gate whose
        // failure has to be reconstructed from the log gets rerun until it passes.
        function countGate(metric, actual, expected) {
            verify(actual === expected,
                   "GATE `%1` = %2, baseline %3 (%4) - the wallet section instantiates a "
                   .arg(metric).arg(actual).arg(expected).arg(signed(actual - expected))
                   + "different set of objects than it did at baseline")
        }

        function signed(delta) {
            return delta > 0 ? "+" + delta : String(delta)
        }

        function printStaircase() {
            const lines = [
                "",
                "wallet section load staircase (whale profile, HOST ms - x10 for low-end Android)",
                "  metric                    value  role",
                "  t_skeleton_ms       %1  recorded".arg(pad(probe.stampMs("t_skeleton"))),
                "  t_ready_ms          %1  recorded".arg(pad(probe.stampMs("t_ready"))),
                "  t_content_ms        %1  recorded (headline)".arg(pad(probe.stampMs("t_content"))),
                "  t_first_asset_row_ms %1  recorded".arg(pad(d.firstAssetRowMs)),
                "  stalls_over_4ms     %1  gated (<= %2)".arg(pad(probe.stallCount)).arg(maxStallsOver4ms),
                "  max_stall_ms        %1  recorded".arg(pad(probe.maxStallMs)),
                "  probe_ticks         %1  recorded".arg(pad(probe.stallTickCount)),
                "  objects_total       %1  gated".arg(pad(d.objectsTotal)),
                "  account_delegates   %1  gated".arg(pad(d.accountDelegates)),
                "  asset_delegates     %1  gated".arg(pad(d.assetDelegates)),
                "  loading_asset_del.  %1  gated".arg(pad(d.loadingAssetDelegates)),
                "  objects_settled     %1  gated".arg(pad(d.objectsSettled)),
                "  asset_deleg_settled %1  gated".arg(pad(d.assetDelegatesSettled)),
                ""
            ]
            for (const line of lines)
                console.info(line)
        }

        function pad(value) {
            const text = typeof value === "number" && !Number.isInteger(value)
                       ? probe.formatMs(value) : String(value)
            return text.padStart(10)
        }

        function recordRow() {
            const profile = "whale-%1a-%2g-%3c"
                            .arg(walletMock.accountCount)
                            .arg(walletMock.assetGroupCount)
                            .arg(walletMock.collectibleCount)
            const row = [
                probe.utcTimestamp(), profile,
                probe.formatMs(probe.stampMs("t_skeleton")),
                probe.formatMs(probe.stampMs("t_ready")),
                probe.formatMs(probe.stampMs("t_content")),
                probe.formatMs(d.firstAssetRowMs),
                String(probe.stallCount),
                probe.formatMs(probe.maxStallMs),
                String(probe.stallTickCount),
                String(d.objectsTotal), String(d.accountDelegates),
                String(d.assetDelegates), String(d.loadingAssetDelegates),
                String(d.objectsSettled), String(d.assetDelegatesSettled)
            ]
            verify(probe.appendTsvRow(tsvPath, tsvHeader, row),
                   "could not append the bench row to " + tsvPath)
        }
    }
}
