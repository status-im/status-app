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
            probe.end()
            d.takeInstantiationCounts()
        }

        // Taken at the t_content stamp rather than after it: anything the
        // section keeps incubating afterwards would make the counts depend on
        // when the test happened to look.
        function takeInstantiationCounts() {
            const section = d.section
            d.objectsTotal = probe.countObjects(section)
            d.accountDelegates = probe.countByObjectNamePrefix(section, "walletAccountListItem")
            d.assetDelegates = probe.countByObjectNamePrefix(section, "AssetView_TokenListItem_")
            d.loadingAssetDelegates = probe.countByObjectNamePrefix(
                        section, "AssetView_LoadingTokenDelegate_")
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
            "stalls_over_4ms", "max_stall_ms", "probe_ticks",
            "objects_total", "account_delegates", "asset_delegates",
            "loading_asset_delegates"
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

        // A ratchet on today's measured count (6-7 over ten runs, one tick of
        // headroom), not the 0 the host budget would want: the section blocks
        // the GUI thread for ~345ms of its ~500ms load, so 4ms-clean is several
        // optimisations away. Lower this whenever a fix lowers the count.
        readonly property int maxStallsOver4ms: 8

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

            printStaircase()
            recordRow()

            compare(d.accountDelegates, expectedAccountDelegates,
                    "instantiation count `account_delegates` changed")
            compare(d.assetDelegates, expectedAssetDelegates,
                    "instantiation count `asset_delegates` changed")
            compare(d.loadingAssetDelegates, expectedLoadingAssetDelegates,
                    "instantiation count `loading_asset_delegates` changed")
            verify(Math.abs(d.objectsTotal - expectedObjectsTotal) <= objectsTotalTolerance,
                   "instantiation count `objects_total` changed: %1, expected %2 +/- %3"
                   .arg(d.objectsTotal).arg(expectedObjectsTotal).arg(objectsTotalTolerance))
            verify(probe.stallCount <= maxStallsOver4ms,
                   "stall probe: `stalls_over_4ms` is %1, over the allowed %2 (host ms, 1ms probe)"
                   .arg(probe.stallCount).arg(maxStallsOver4ms))
        }

        function printStaircase() {
            const lines = [
                "",
                "wallet section load staircase (whale profile, HOST ms - x10 for low-end Android)",
                "  metric                    value  role",
                "  t_skeleton_ms       %1  recorded".arg(pad(probe.stampMs("t_skeleton"))),
                "  t_ready_ms          %1  recorded".arg(pad(probe.stampMs("t_ready"))),
                "  t_content_ms        %1  recorded (headline)".arg(pad(probe.stampMs("t_content"))),
                "  stalls_over_4ms     %1  gated (<= %2)".arg(pad(probe.stallCount)).arg(maxStallsOver4ms),
                "  max_stall_ms        %1  recorded".arg(pad(probe.maxStallMs)),
                "  probe_ticks         %1  recorded".arg(pad(probe.stallTickCount)),
                "  objects_total       %1  gated".arg(pad(d.objectsTotal)),
                "  account_delegates   %1  gated".arg(pad(d.accountDelegates)),
                "  asset_delegates     %1  gated".arg(pad(d.assetDelegates)),
                "  loading_asset_del.  %1  gated".arg(pad(d.loadingAssetDelegates)),
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
                String(probe.stallCount),
                probe.formatMs(probe.maxStallMs),
                String(probe.stallTickCount),
                String(d.objectsTotal), String(d.accountDelegates),
                String(d.assetDelegates), String(d.loadingAssetDelegates)
            ]
            verify(probe.appendTsvRow(tsvPath, tsvHeader, row),
                   "could not append the bench row to " + tsvPath)
        }
    }
}
