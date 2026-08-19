import QtQuick
import QtTest

import StatusQ
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
// Each run loads the section twice and records a row per phase. The **warm**
// phase - the second load in the same process - is the headline: ~90% of a cold
// load is one-time process warm-up the app has already paid before a user ever
// reaches the wallet, so steering by the cold number sends optimisation work
// after a cost nobody experiences. Cold stays recorded as a canary: cold moving
// while warm holds still means someone added first-use cost, which matters for
// app start-up.
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

        property int objectsPerAssetRow: -1
        property var stallTimeline: []
        property var stampList: []

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

        // Everything the previous phase latched must go before the next one:
        // a stale loader reference would satisfy the content stop line before
        // the new section has built anything.
        function resetPhase() {
            d.section = null
            d.accountsListLoader = null
            d.mainViewLoader = null
            d.accountsListLoaders = []
            d.mainViewLoaders = []
            d.objectsTotal = -1
            d.accountDelegates = -1
            d.assetDelegates = -1
            d.loadingAssetDelegates = -1
            d.firstAssetRowMs = -1
            d.objectsSettled = -1
            d.assetDelegatesSettled = -1
            d.objectsPerAssetRow = -1
            d.stallTimeline = []
            d.stampList = []
        }

        function snapshot(phase) {
            return ({
                phase: phase,
                skeletonMs: probe.stampMs("t_skeleton"),
                readyMs: probe.stampMs("t_ready"),
                contentMs: probe.stampMs("t_content"),
                firstAssetRowMs: d.firstAssetRowMs,
                stalls: probe.stallCount,
                maxStallMs: probe.maxStallMs,
                probeTicks: probe.stallTickCount,
                objectsTotal: d.objectsTotal,
                accountDelegates: d.accountDelegates,
                assetDelegates: d.assetDelegates,
                loadingAssetDelegates: d.loadingAssetDelegates,
                objectsSettled: d.objectsSettled,
                assetDelegatesSettled: d.assetDelegatesSettled,
                objectsPerAssetRow: d.objectsPerAssetRow,
                stallTimeline: d.stallTimeline,
                stampTimeline: d.stampList
            })
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
            const firstRow = probe.findByObjectNamePrefix(d.section, "AssetView_TokenListItem_")
            d.objectsPerAssetRow = firstRow ? probe.countObjects(firstRow) : -1
            d.stallTimeline = probe.stalls()
            d.stampList = probe.stampTimeline()
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
            "utc_time", "profile", "phase",
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
        readonly property int expectedObjectsSettled: 9166
        readonly property int expectedAssetDelegatesSettled: 26

        // Ratchets on the measured counts (warm 13-16, cold 16-17 over eight
        // phase runs), not the 0 the host budget would want: the section blocks the
        // GUI thread for most of its load, so 4ms-clean is several optimisations
        // away. Lower these whenever a fix lowers the measured count.
        //
        // The count rose when the assets rows became preemptible (issues/0007)
        // and the cold ratchet now has no headroom left. That is the metric, not
        // the surface, misbehaving: the incubation controller's gentle bite is
        // 4ms (printed per run below), exactly this gate's threshold, so every
        // metered bite scores as a stall and chopping one 35ms block into eight
        // 4ms bites counts as seven extra stalls. Whoever changes the controller
        // budget (PR #21921) owns this.
        readonly property int maxWarmStallsOver4ms: 16
        readonly property int maxColdStallsOver4ms: 16

        function initTestCase() {
            WalletStores.RootStore.palette = Theme.palette
        }

        function cleanupTestCase() {
            harness.active = false
            walletMock.uninstall()
        }

        function test_walletSectionLoadStaircase() {
            walletMock.install()

            const cold = loadPhase("cold")
            teardownSection()
            const warm = loadPhase("warm")

            printStaircase(cold, warm)
            printTimeline(cold)
            printTimeline(warm)
            if (probe.samplingEnabled) {
                const dump = probe.sampleDumpPath
                verify(probe.dumpSamples(dump), "could not write the sampler dump")
                console.info("stack samples written to " + dump)
            }
            recordRow(cold)
            recordRow(warm)

            // Gated on both phases: these are load-invariant, and that they are
            // is itself the claim - the section must build the same objects
            // whether or not the process has seen it before.
            for (const phase of [cold, warm]) {
                countGate(phase, "objects_settled", phase.objectsSettled, expectedObjectsSettled)
                countGate(phase, "asset_delegates_settled", phase.assetDelegatesSettled,
                          expectedAssetDelegatesSettled)
                countGate(phase, "account_delegates", phase.accountDelegates,
                          expectedAccountDelegates)
                countGate(phase, "asset_delegates", phase.assetDelegates, expectedAssetDelegates)
                countGate(phase, "loading_asset_delegates", phase.loadingAssetDelegates,
                          expectedLoadingAssetDelegates)
            }

            // `objects_total` is the count at the loaders-Ready stop line, which
            // on a warm load races the layout pass that follows it - gated on
            // the cold phase only, where it is exactly reproducible.
            countGate(cold, "objects_total", cold.objectsTotal, expectedObjectsTotal)

            stallGate(warm, maxWarmStallsOver4ms)
            stallGate(cold, maxColdStallsOver4ms)
        }

        // One load of the section, from `active = true` to the settle point.
        function loadPhase(phase) {
            d.resetPhase()

            probe.begin()
            harness.active = true
            // Everything the loader builds synchronously - the section chrome
            // and both skeleton panels - exists by the time the assignment
            // returns; that is the time-to-skeleton stop line.
            probe.stamp("t_skeleton")

            const skeleton = probe.findByTypePrefix(harness.item, "WalletAccountsSkeleton")
            verify(!!skeleton,
                   "%1: time-to-skeleton, no WalletAccountsSkeleton in the section chrome"
                   .arg(phase))
            verify(skeleton.visible,
                   "%1: time-to-skeleton, the accounts skeleton is not visible".arg(phase))

            verify(probe.waitForStamp("t_ready", 60000),
                   "%1: the wallet section never reached Loader.Ready".arg(phase))

            verify(!!d.accountsListLoader,
                   "%1: time-to-content, could not locate the accounts list loader - the "
                   .arg(phase)
                   + "left panel holds %1 asynchronous Loaders, expected exactly one"
                   .arg(d.accountsListLoaders.length))
            verify(!!d.mainViewLoader,
                   "%1: time-to-content, could not locate the main view loader - the "
                   .arg(phase)
                   + "center panel holds %1 asynchronous Loaders, expected exactly one"
                   .arg(d.mainViewLoaders.length))

            verify(probe.waitForStamp("t_content", 60000),
                   "%1: time-to-content, the accounts list and the main view never both "
                   .arg(phase) + "reached Loader.Ready")

            d.settle(60000)
            verify(d.firstAssetRowMs < 60000,
                   "%1: the assets list never realised a row after time-to-content".arg(phase))

            return d.snapshot(phase)
        }

        // Destroys the section but not the engine: the QML types, the store
        // singletons and everything else the first load warmed up stay, which
        // is what makes the next load the warm one.
        function teardownSection() {
            harness.active = false
            probe.waitForStamp("never-stamped", 200)
        }

        // One line carrying metric, both numbers and the delta: a gate whose
        // failure has to be reconstructed from the log gets rerun until it passes.
        function countGate(phase, metric, actual, expected) {
            verify(actual === expected,
                   "GATE `%1` [%2 load] = %3, baseline %4 (%5) - the wallet section "
                   .arg(metric).arg(phase.phase).arg(actual).arg(expected)
                   .arg(signed(actual - expected))
                   + "instantiates a different set of objects than it did at baseline")
        }

        function stallGate(phase, allowed) {
            verify(phase.stalls <= allowed,
                   "GATE `stalls_over_4ms` [%1 load] = %2, baseline allows %3 (%4) - host ms, "
                   .arg(phase.phase).arg(phase.stalls).arg(allowed)
                   .arg(signed(phase.stalls - allowed))
                   + "1ms probe, window is the whole load up to the settle point")
        }

        function signed(delta) {
            return delta > 0 ? "+" + delta : String(delta)
        }

        function printStaircase(cold, warm) {
            const lines = [
                "",
                "wallet section load staircase (whale profile, HOST ms - x10 for low-end Android)",
                "  metric                        warm        cold  role",
                row("t_skeleton_ms", warm.skeletonMs, cold.skeletonMs, "recorded"),
                row("t_ready_ms", warm.readyMs, cold.readyMs, "recorded"),
                row("t_content_ms", warm.contentMs, cold.contentMs, "recorded"),
                row("t_first_asset_row_ms", warm.firstAssetRowMs, cold.firstAssetRowMs,
                    "recorded (HEADLINE: warm)"),
                row("stalls_over_4ms", warm.stalls, cold.stalls,
                    "gated (warm <= %1, cold <= %2)".arg(maxWarmStallsOver4ms)
                    .arg(maxColdStallsOver4ms)),
                row("max_stall_ms", warm.maxStallMs, cold.maxStallMs, "recorded"),
                row("probe_ticks", warm.probeTicks, cold.probeTicks, "recorded"),
                row("objects_total", warm.objectsTotal, cold.objectsTotal, "gated (cold only)"),
                row("account_delegates", warm.accountDelegates, cold.accountDelegates, "gated"),
                row("asset_delegates", warm.assetDelegates, cold.assetDelegates, "gated"),
                row("loading_asset_deleg.", warm.loadingAssetDelegates,
                    cold.loadingAssetDelegates, "gated"),
                row("objects_settled", warm.objectsSettled, cold.objectsSettled, "gated"),
                row("asset_delegates_settled", warm.assetDelegatesSettled,
                    cold.assetDelegatesSettled, "gated"),
                "",
                "  warm = second load in the same process; cold = first. The app has paid",
                "  most of the cold-only cost before a user reaches the wallet.",
                ""
            ]
            for (const line of lines)
                console.info(line)
        }

        // Attribution view (issues/0006): where the GUI-thread blocks sit inside
        // the window, against the staircase stamps.
        function printTimeline(phase) {
            console.info("")
            console.info("%1 phase - stamp timeline (host ms)".arg(phase.phase))
            for (const stamp of phase.stampTimeline)
                console.info("    %1  %2".arg(probe.formatMs(stamp.ms).padStart(10))
                             .arg(stamp.name))
            console.info("%1 phase - objects per realised assets row: %2"
                         .arg(phase.phase).arg(phase.objectsPerAssetRow))
            // The controller's bite budget is the floor of every block in the
            // incubated phase, so it is printed next to them.
            const incubation = IncubationHints.stats()
            console.info("%1 phase - GUI-thread blocks over %2ms (host ms); gentle incubation bite %3ms every %4ms"
                         .arg(phase.phase).arg(probe.stallThresholdMs)
                         .arg(incubation.gentleBudgetMs).arg(incubation.gentleIntervalMs))
            for (const stall of phase.stallTimeline)
                console.info("    %1 -> %2   %3".arg(probe.formatMs(stall.startMs).padStart(10))
                             .arg(probe.formatMs(stall.endMs).padStart(10))
                             .arg(probe.formatMs(stall.gapMs).padStart(8)))
            console.info("")
        }

        function row(metric, warmValue, coldValue, role) {
            return "  %1%2%3  %4".arg(metric.padEnd(24)).arg(pad(warmValue))
                                 .arg(pad(coldValue)).arg(role)
        }

        function pad(value) {
            const text = typeof value === "number" && !Number.isInteger(value)
                       ? probe.formatMs(value) : String(value)
            return text.padStart(10)
        }

        function recordRow(phase) {
            const profile = "whale-%1a-%2g-%3c"
                            .arg(walletMock.accountCount)
                            .arg(walletMock.assetGroupCount)
                            .arg(walletMock.collectibleCount)
            const row = [
                probe.utcTimestamp(), profile, phase.phase,
                probe.formatMs(phase.skeletonMs),
                probe.formatMs(phase.readyMs),
                probe.formatMs(phase.contentMs),
                probe.formatMs(phase.firstAssetRowMs),
                String(phase.stalls),
                probe.formatMs(phase.maxStallMs),
                String(phase.probeTicks),
                String(phase.objectsTotal), String(phase.accountDelegates),
                String(phase.assetDelegates), String(phase.loadingAssetDelegates),
                String(phase.objectsSettled), String(phase.assetDelegatesSettled)
            ]
            verify(probe.appendTsvRow(tsvPath, tsvHeader, row),
                   "could not append the %1 bench row to %2".arg(phase.phase).arg(tsvPath))
        }
    }
}
