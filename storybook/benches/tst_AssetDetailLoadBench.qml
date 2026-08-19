import QtQuick
import QtTest

import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import shared.stores as SharedStores

import AppLayouts.stores as AppStores
import AppLayouts.Communities.stores as CommunityStores
import AppLayouts.Wallet.stores as WalletStores

import mainui.sectionLoaders

import Mocks
import Models
import StorybookMocks

// Load bench for the asset detail surface (issues/0002).
//
// This surface only exists as something to measure because the detail views are
// deferred: before that they were plain children of RightTabView's StackLayout,
// already built by the time anyone navigated to them, so "asset detail load
// time" was structurally zero and structurally meaningless.
//
// The section is brought up and settled first, unmeasured. The window then runs
// from the navigation request - the production `assetClicked` path, which picks
// the token group and moves the stack - to the settle point, exactly as the
// section bench does.
//
// Two opens per run, for the same reason the section bench loads twice. Neither
// is privileged as the headline: on this surface the wall clock is quantised by
// the incubation controller's gentle cadence (one ~4ms bite every ~17ms), so
// t_content is `phase offset + bites x 17ms` and both phases land on a small set
// of discrete values. The warm open starts from an idle controller and waits a
// full gentle interval for its first bite; the cold open pays a synchronous
// first-use block at t=0 but its bite train has already started. That, not
// anything accumulating across the unload/reload cycle, is why the second open
// can read slower than the first - see issues/0012.
//
// Budget: popup class, 400ms device / 40ms host (docs/investigations/
// wallet-load-benchmarks.md). All numbers are HOST units.
Item {
    id: root

    width: 1440
    height: 900

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
                if (status === Loader.Ready)
                    d.section = walletLoader
            }
        }
    }

    // The detail loader's own status is the time-to-ready stop line.
    Connections {
        target: d.detailLoader
        function onStatusChanged() {
            if (d.detailLoader.status === Loader.Ready)
                probe.stamp("t_ready")
        }
    }

    QtObject {
        id: d

        property var section: null
        property var detailLoader: null
        property var assetsView: null

        property real contentMs: -1
        property real settledMs: -1
        property int objectsAtReady: -1
        property int objectsSettled: -1
        property int chainTags: -1
        property int informationTiles: -1
        property var stallTimeline: []
        property var stampList: []

        function detailItem() {
            return d.detailLoader ? d.detailLoader.item : null
        }

        // Realised content, not merely Loader.Ready: the view has been through a
        // layout pass (non-zero size) and its header has produced the per-chain
        // balance tags, which is the work the deferral moved off the section
        // load. `communityTag` is a static child of the header and would satisfy
        // a bare "any InformationTag exists" test on the frame the item is
        // created, so the chain tags are counted separately by object name.
        function contentRealised() {
            const item = d.detailItem()
            if (!item || item.width <= 0 || item.height <= 0)
                return false
            return probe.countByObjectNamePrefix(item, "assetsDetailsHeaderChainTag_") > 0
        }

        function spin(ms) {
            probe.waitForStamp("never-stamped", ms)
        }

        function resetPhase() {
            d.detailLoader = null
            d.contentMs = -1
            d.settledMs = -1
            d.objectsAtReady = -1
            d.objectsSettled = -1
            d.chainTags = -1
            d.informationTiles = -1
            d.stallTimeline = []
            d.stampList = []
        }

        function snapshot(phase) {
            return ({
                phase: phase,
                readyMs: probe.stampMs("t_ready"),
                contentMs: d.contentMs,
                settledMs: d.settledMs,
                stalls: probe.stallCount,
                maxStallMs: probe.maxStallMs,
                probeTicks: probe.stallTickCount,
                objectsAtReady: d.objectsAtReady,
                objectsSettled: d.objectsSettled,
                chainTags: d.chainTags,
                informationTiles: d.informationTiles,
                stallTimeline: d.stallTimeline,
                stampTimeline: d.stampList
            })
        }
    }

    TestCase {
        name: "AssetDetailLoadBench"
        when: windowShown

        readonly property string tsvPath:
            probe.sourceDir + "/benches/baselines/asset-detail-load.tsv"

        readonly property var tsvHeader: [
            "utc_time", "profile", "phase",
            "t_ready_ms", "t_content_ms", "t_settled_ms",
            "stalls_over_4ms", "max_stall_ms", "probe_ticks",
            "objects_at_ready", "objects_settled",
            "chain_tags", "information_tiles"
        ]

        // Host budget for a popup-class surface: 400ms device / 10. Recorded,
        // not gated: the surface does not meet it (t_content 48-76ms over ten
        // phase runs) and a gate nobody can pass is a disabled gate. 40ms is a
        // two-bite budget on this cadence and the view needs three.
        readonly property real contentBudgetMs: 40

        // Gated on both phases. `objects_settled` carries a documented tolerance
        // of 1 rather than a rounder number: the drain loop's stability test can
        // end one sample before a late tooltip lands. A regression worth
        // catching here moves the count by hundreds, not by one.
        // `objects_at_ready` is recorded only: it races the layout pass that
        // follows Ready.
        readonly property int expectedObjectsSettled: 916
        readonly property int objectsSettledTolerance: 1
        readonly property int expectedChainTags: 4
        readonly property int expectedInformationTiles: 2

        // Ratchet on the observed maximum over ten runs per phase on the merged
        // tree (issues/0018): warm 2-6, cold 8-11. Lower it whenever a fix
        // lowers the measured count; never raise it.
        readonly property int maxStallsOver4ms: 11

        function initTestCase() {
            WalletStores.RootStore.palette = Theme.palette
        }

        function cleanupTestCase() {
            harness.active = false
            walletMock.uninstall()
        }

        function test_assetDetailLoadStaircase() {
            walletMock.install()

            bringSectionUp()

            const cold = openDetail("cold")
            closeDetail()
            const warm = openDetail("warm")

            printStaircase(cold, warm)
            printTimeline(cold)
            printTimeline(warm)
            recordRow(cold)
            recordRow(warm)

            for (const phase of [cold, warm]) {
                countGate(phase, "objects_settled", phase.objectsSettled, expectedObjectsSettled,
                          objectsSettledTolerance)
                countGate(phase, "chain_tags", phase.chainTags, expectedChainTags)
                countGate(phase, "information_tiles", phase.informationTiles,
                          expectedInformationTiles)
                stallGate(phase, maxStallsOver4ms)
            }
        }

        function countGate(phase, metric, actual, expected, tolerance = 0) {
            verify(Math.abs(actual - expected) <= tolerance,
                   "GATE `%1` [%2 open] = %3, baseline %4 +/- %5 (%6) - the asset detail "
                   .arg(metric).arg(phase.phase).arg(actual).arg(expected).arg(tolerance)
                   .arg(signed(actual - expected))
                   + "instantiates a different set of objects than it did at baseline")
        }

        function stallGate(phase, allowed) {
            verify(phase.stalls <= allowed,
                   "GATE `stalls_over_4ms` [%1 open] = %2, baseline allows %3 (%4) - host ms, "
                   .arg(phase.phase).arg(phase.stalls).arg(allowed)
                   .arg(signed(phase.stalls - allowed))
                   + "1ms probe, window is the whole open up to the settle point")
        }

        function signed(delta) {
            return delta > 0 ? "+" + delta : String(delta)
        }

        // Unmeasured: the section must be up and settled before the detail
        // surface can be requested at all, and its cost is the other bench's.
        function bringSectionUp() {
            probe.begin()
            harness.active = true

            const deadline = probe.elapsedMs + 60000
            while (!d.section && probe.elapsedMs < deadline)
                d.spin(1)
            verify(!!d.section, "the wallet section never reached Loader.Ready")

            const layout = d.section.item
            d.assetsView = probe.findByTypePrefix(layout.centerPanel, "AssetsView")
            verify(!!d.assetsView, "no AssetsView in the section's center panel")

            while (probe.countByObjectNamePrefix(d.section, "AssetView_TokenListItem_") === 0
                   && probe.elapsedMs < deadline)
                d.spin(1)
            verify(probe.countByObjectNamePrefix(d.section, "AssetView_TokenListItem_") > 0,
                   "the assets list never realised a row, so nothing can be clicked")
            probe.end()
        }

        // One open of the asset detail, from the navigation request to the
        // settle point.
        function openDetail(phase) {
            d.resetPhase()

            const layout = d.section.item
            d.detailLoader = probe.findByObjectNamePrefix(layout.centerPanel, "assetDetailLoader")
            verify(!!d.detailLoader,
                   "%1: no assetDetailLoader in the section - the asset detail is not deferred"
                   .arg(phase))
            verify(!d.detailLoader.active,
                   "%1: the asset detail loader is already active before the request".arg(phase))

            const key = SQUtils.ModelUtils.get(d.assetsView.model, 0, "key")
            verify(!!key, "%1: the assets model has no first row to open".arg(phase))

            probe.begin()
            // The production navigation path: the view's own signal, which picks
            // the token group and moves the stack.
            d.assetsView.assetClicked(key)

            verify(probe.waitForStamp("t_ready", 60000),
                   "%1: the asset detail loader never reached Loader.Ready".arg(phase))
            d.objectsAtReady = probe.countObjects(detailItemOrFail(phase))

            const deadline = probe.elapsedMs + 60000
            while (!d.contentRealised() && probe.elapsedMs < deadline)
                d.spin(1)
            verify(d.contentRealised(),
                   "%1: the asset detail never realised its content".arg(phase))
            d.contentMs = probe.elapsedMs

            let previous = -1
            let current = probe.countObjects(d.detailItem())
            while (current !== previous && probe.elapsedMs < deadline) {
                previous = current
                d.spin(50)
                current = probe.countObjects(d.detailItem())
            }
            d.settledMs = probe.elapsedMs
            probe.end()

            d.objectsSettled = current
            d.chainTags = probe.countByObjectNamePrefix(d.detailItem(), "assetsDetailsHeaderChainTag_")
            d.informationTiles = probe.countByTypePrefix(d.detailItem(), "InformationTileAssetDetails")
            d.stallTimeline = probe.stalls()
            d.stampList = probe.stampTimeline()

            return d.snapshot(phase)
        }

        function detailItemOrFail(phase) {
            const item = d.detailItem()
            verify(!!item, "%1: the asset detail loader is Ready with no item".arg(phase))
            return item
        }

        // Back out of the detail the way the chrome's back button does.
        function closeDetail() {
            d.section.item.handleBackButtonClicked()
            d.spin(200)
            verify(!d.detailLoader.active,
                   "the asset detail loader is still active after navigating back")
            verify(!d.detailLoader.item,
                   "the asset detail item survived the navigation back")
        }

        function printStaircase(cold, warm) {
            const lines = [
                "",
                "asset detail load staircase (whale profile, HOST ms - x10 for low-end Android)",
                "  metric                        warm        cold  role",
                row("t_ready_ms", warm.readyMs, cold.readyMs, "recorded"),
                row("t_content_ms", warm.contentMs, cold.contentMs,
                    "recorded (HEADLINE, budget %1)".arg(contentBudgetMs)),
                row("t_settled_ms", warm.settledMs, cold.settledMs, "recorded"),
                row("stalls_over_4ms", warm.stalls, cold.stalls, "gated (<= %1)".arg(maxStallsOver4ms)),
                row("max_stall_ms", warm.maxStallMs, cold.maxStallMs, "recorded"),
                row("probe_ticks", warm.probeTicks, cold.probeTicks, "recorded"),
                row("objects_at_ready", warm.objectsAtReady, cold.objectsAtReady, "recorded"),
                row("objects_settled", warm.objectsSettled, cold.objectsSettled, "gated"),
                row("chain_tags", warm.chainTags, cold.chainTags, "gated"),
                row("information_tiles", warm.informationTiles, cold.informationTiles, "gated"),
                "",
                "  budget: t_content %1 / %2 host ms against %3 (popup class, 400ms device)"
                .arg(probe.formatMs(cold.contentMs)).arg(probe.formatMs(warm.contentMs))
                .arg(contentBudgetMs),
                "  t_settled includes the two 50ms stability samples the drain loop needs;",
                "  it is a drain point, not a rung of the staircase.",
                ""
            ]
            for (const line of lines)
                console.info(line)
        }

        function printTimeline(phase) {
            console.info("")
            console.info("%1 open - stamp timeline (host ms)".arg(phase.phase))
            for (const stamp of phase.stampTimeline)
                console.info("    %1  %2".arg(probe.formatMs(stamp.ms).padStart(10))
                             .arg(stamp.name))
            console.info("%1 open - GUI-thread blocks over %2ms (host ms)"
                         .arg(phase.phase).arg(probe.stallThresholdMs))
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
                probe.formatMs(phase.readyMs),
                probe.formatMs(phase.contentMs),
                probe.formatMs(phase.settledMs),
                String(phase.stalls),
                probe.formatMs(phase.maxStallMs),
                String(phase.probeTicks),
                String(phase.objectsAtReady), String(phase.objectsSettled),
                String(phase.chainTags), String(phase.informationTiles)
            ]
            verify(probe.appendTsvRow(tsvPath, tsvHeader, row),
                   "could not append the %1 bench row to %2".arg(phase.phase).arg(tsvPath))
        }
    }
}
