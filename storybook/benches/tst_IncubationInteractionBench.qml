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

// Interaction-during-incubation bench (issues/0023).
//
// The load benches answer "how fast does content arrive"; they cannot answer
// "what does incubation cost whoever else wants the GUI thread", because in
// them nobody else does. This one runs a scroll and a section load at the same
// time and measures the scroll.
//
// Method
//   1. A long list scrolls at a fixed pixel rate under a linear animation, so
//      every frame realises delegates - a frame with real work of its own.
//   2. `IncubationHints.pushGentle()` is held for the whole scroll. That is the
//      regime under test: the gentle cadence exists for exactly the case where
//      an interaction is in progress, and without the hint a burst leaves the
//      gentle phase after `gentlePeriodMs` and the measurement would be of the
//      boosted phase instead.
//   3. After a baseline window of scrolling alone, the wallet section is
//      activated and incubates while the scroll continues.
//   4. Frames are counted on `QQuickWindow::afterAnimating` - the GUI thread's
//      own per-frame beat, so a gap between two of them is a frame the loop did
//      not get to run.
//
// The comparison is within-run: the same scroll, before / during / after the
// incubation window. That makes the arms readable under machine load, which a
// raw frame count would not be.
//
// MUST RUN ON SCREEN. Frame pacing is the measurement; offscreen there is no
// display to pace against.
//
// To A/B a cadence, add two `qEnvironmentVariableIntValue` reads over
// `m_gentleIntervalMs` / `m_gentleBudgetMs` in `BoostedIncubationController`'s
// constructor (externc.cpp) and alternate arms between runs; the constants are
// compile-time and this bench deliberately does not ship a hook into them.
//
// Knobs (env): BENCH_SCROLL_PX_PER_S, BENCH_FRAME_LOAD_MS (synthetic per-frame
// GUI work, to sweep how much of its own work a frame can have before the
// cadence matters), BENCH_PRE_MS (control window), BENCH_ROUNDS.
Item {
    id: root

    width: 1440
    height: 900

    readonly property int scrollPxPerS: envInt("BENCH_SCROLL_PX_PER_S", 9000)
    readonly property real frameLoadMs: envInt("BENCH_FRAME_LOAD_MS", 0)
    readonly property int preMs: envInt("BENCH_PRE_MS", 1200)
    readonly property int rounds: envInt("BENCH_ROUNDS", 6)

    function envInt(name, fallback) {
        const raw = probe.env(name)
        const parsed = parseInt(raw)
        return isNaN(parsed) ? fallback : parsed
    }

    WalletLoadBenchProbe { id: probe }

    // Whale profile: the mock's own defaults, as the wallet bench uses them.
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

    ListModel { id: scrollModel }

    // The interaction surface. Left half of the window so the incubating
    // section has somewhere to paint; both are on screen and both are polished.
    ListView {
        id: scrollList

        width: parent.width / 2
        height: parent.height
        model: scrollModel
        cacheBuffer: 0
        clip: true

        delegate: Item {
            required property int index
            required property string label

            width: ListView.view.width
            height: 64

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: 8
                color: index % 2 ? Theme.palette.baseColor4 : Theme.palette.baseColor5
                border.color: Theme.palette.baseColor2

                Rectangle {
                    id: avatar
                    width: 40; height: 40; radius: 20
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    color: Theme.palette.primaryColor1
                }

                Column {
                    anchors.left: avatar.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: label
                        font.pixelSize: 15
                        color: Theme.palette.directColor1
                    }
                    Text {
                        text: "a secondary line that has to be laid out too - row " + index
                        font.pixelSize: 12
                        color: Theme.palette.baseColor1
                    }
                    Text {
                        text: "0x%1".arg((index * 7919).toString(16))
                        font.pixelSize: 11
                        color: Theme.palette.baseColor1
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: scroll
        target: scrollList
        property: "contentY"
        from: 0
        easing.type: Easing.Linear
    }

    // Per-frame synthetic load, on the GUI thread, for the frame-cost sweep.
    FrameAnimation {
        id: frameLoad
        running: false
        onTriggered: probe.burnMs(root.frameLoadMs)
    }

    // Synchronous on purpose: activating it starts the incubation window.
    Loader {
        id: harness

        width: parent.width / 2
        height: parent.height
        x: parent.width / 2
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
                    probe.stamp("t_ready")
            }
        }
    }

    TestCase {
        name: "IncubationInteractionBench"
        when: windowShown

        function initTestCase() {
            probe.raiseWindow(root)
            WalletStores.RootStore.palette = Theme.palette
            for (let i = 0; i < 4000; ++i)
                scrollModel.append({ label: "Row " + i })
        }

        function cleanupTestCase() {
            harness.active = false
            walletMock.uninstall()
        }

        // Spins the event loop for `ms` without sleeping in it: TestCase.wait
        // and tryVerify both starve the 1ms probe (see the harness findings).
        function spin(ms) {
            probe.waitForStamp("never-stamped", ms)
        }

        function test_scrollDuringSectionIncubation() {
            walletMock.install()
            probe.raiseWindow(root)

            // Warm-up load, discarded: a cold section pays one-time QML compile
            // cost that is an order of magnitude larger than anything the
            // cadence does, and the app has already paid it before a user
            // interacts with anything.
            harness.active = true
            waitForIncubationDrain(30000)
            harness.active = false
            spin(400)

            // Let the list realise its first screenful before the clock starts.
            spin(400)
            scroll.duration = 60000
            scroll.to = root.scrollPxPerS * 60
            scroll.start()
            frameLoad.running = true
            spin(400)

            probe.begin()
            probe.watchFrames(root)
            // The regime under test: an interaction in progress holds the
            // controller gentle for as long as it runs.
            IncubationHints.pushGentle()

            // One load is ~100ms warm, a dozen frames - too few to read. The
            // load is repeated and the windows pooled; the scroll never stops,
            // so the control windows are the same interaction without a section
            // incubating behind it.
            const control = []
            const incubating = []
            for (let round = 0; round < root.rounds; ++round) {
                const controlStart = probe.elapsedMs
                spin(root.preMs)
                control.push({ start: controlStart, end: probe.elapsedMs })

                const incStart = probe.elapsedMs
                harness.active = true
                waitForIncubationDrain(30000)
                incubating.push({ start: incStart, end: probe.elapsedMs })

                harness.active = false
                // The teardown itself churns the GUI thread; it belongs to
                // neither window.
                spin(300)
            }

            IncubationHints.popGentle()
            probe.end()
            scroll.stop()
            frameLoad.running = false

            report(control, incubating)
        }

        // Incubation is over when the controller has nothing left to build.
        // Polled off the controller itself rather than off the section, so the
        // window covers every incubator the load spawns.
        function waitForIncubationDrain(timeoutMs) {
            const deadline = probe.elapsedMs + timeoutMs
            let idleTicks = 0
            while (probe.elapsedMs < deadline) {
                spin(8)
                // Two consecutive idle reads: the count dips to zero between
                // chained incubators, and one dip is not the end of the load.
                idleTicks = IncubationHints.stats().count === 0 ? idleTicks + 1 : 0
                if (idleTicks >= 3)
                    return
            }
        }

        function report(control, incubating) {
            const frames = probe.frameTimes()
            const controlIntervals = intervalsInAll(frames, control)
            const duringIntervals = intervalsInAll(frames, incubating)

            verify(controlIntervals.length > 20,
                   "the control windows produced only %1 frame intervals - this bench must run "
                   .arg(controlIntervals.length) + "on screen, against a real frame loop")

            // Nominal comes from this run's own control windows: the display is
            // variable-refresh, so a constant would be wrong on either arm.
            const nominal = median(controlIntervals)
            // macOS stops rendering an occluded window: a run that lost the
            // foreground reports a short frame record rather than a bad one, and
            // averaging that in would quietly bias whichever arm it hit.
            const expected = root.rounds * root.preMs / nominal
            verify(controlIntervals.length > 0.7 * expected,
                   "only %1 of an expected %2 control frames were rendered - the window lost the "
                   .arg(controlIntervals.length).arg(Math.round(expected))
                   + "foreground mid-run; discard this run")
            const incubation = IncubationHints.stats()
            const incMs = incubating.reduce((a, w) => a + (w.end - w.start), 0) / incubating.length
            const blocks = probe.stalls().filter(
                        stall => incubating.some(w => stall.startMs >= w.start
                                                 && stall.endMs <= w.end))

            console.info("")
            console.info("interaction during incubation - %1ms bite every %2ms (%3% duty), "
                         .arg(incubation.gentleBudgetMs).arg(incubation.gentleIntervalMs)
                         .arg(Math.round(100 * incubation.gentleBudgetMs
                                         / incubation.gentleIntervalMs))
                         + "scroll %1px/s, synthetic frame load %2ms, %3 rounds"
                         .arg(root.scrollPxPerS).arg(root.frameLoadMs).arg(root.rounds))
            console.info("  nominal frame interval %1ms (median of the control windows)"
                         .arg(probe.formatMs(nominal)))
            console.info("  window     frames   median      p95      max   late>1.5x  late>2x   late%")
            printWindow("control", controlIntervals, nominal)
            printWindow("during", duringIntervals, nominal)
            console.info("  incubation window %1ms mean over %2 rounds; %3 GUI-thread blocks "
                         .arg(probe.formatMs(incMs)).arg(incubating.length).arg(blocks.length)
                         + "over %1ms inside them, max %2ms".arg(probe.stallThresholdMs)
                         .arg(probe.formatMs(blocks.reduce((a, s) => Math.max(a, s.gapMs), 0))))

            // One machine-parseable line per run, for the A/B driver.
            console.info("RESULT bite=%1 interval=%2 frameLoad=%3 scroll=%4 nominal=%5 incMs=%6 "
                         .arg(incubation.gentleBudgetMs).arg(incubation.gentleIntervalMs)
                         .arg(root.frameLoadMs).arg(root.scrollPxPerS)
                         .arg(probe.formatMs(nominal)).arg(probe.formatMs(incMs))
                         + "ctlLate=%1 ctlN=%2 incLate=%3 incN=%4 "
                         .arg(lateCount(controlIntervals, nominal, 1.5))
                         .arg(controlIntervals.length)
                         .arg(lateCount(duringIntervals, nominal, 1.5))
                         .arg(duringIntervals.length)
                         + "incMedian=%1 incP95=%2 incMax=%3 blocks=%4 blockMax=%5"
                         .arg(probe.formatMs(median(duringIntervals)))
                         .arg(probe.formatMs(percentile(duringIntervals, 0.95)))
                         .arg(probe.formatMs(Math.max(...duringIntervals)))
                         .arg(blocks.length)
                         .arg(probe.formatMs(blocks.reduce((a, s) => Math.max(a, s.gapMs), 0))))
            console.info("")
        }

        function printWindow(name, intervals, nominal) {
            console.info("  %1%2%3%4%5%6%7%8"
                         .arg(name.padEnd(9))
                         .arg(String(intervals.length).padStart(7))
                         .arg(probe.formatMs(median(intervals)).padStart(9))
                         .arg(probe.formatMs(percentile(intervals, 0.95)).padStart(9))
                         .arg(probe.formatMs(Math.max(...intervals)).padStart(9))
                         .arg(String(lateCount(intervals, nominal, 1.5)).padStart(12))
                         .arg(String(lateCount(intervals, nominal, 2.0)).padStart(9))
                         .arg(("%1%".arg(Math.round(1000 * lateCount(intervals, nominal, 1.5)
                                                    / intervals.length) / 10)).padStart(8)))
        }

        // Only intervals whose whole span sits inside a window are counted, so
        // the block that spans a window boundary is not charged to it twice.
        function intervalsInAll(frames, windows) {
            let out = []
            for (const window of windows)
                out = out.concat(intervalsIn(frames, window.start, window.end))
            return out
        }

        function intervalsIn(frames, fromMs, toMs) {
            const out = []
            for (let i = 1; i < frames.length; ++i) {
                if (frames[i] > fromMs && frames[i] <= toMs)
                    out.push(frames[i] - frames[i - 1])
            }
            return out
        }

        function lateCount(intervals, nominal, factor) {
            return intervals.filter(v => v > nominal * factor).length
        }

        function median(values) {
            return percentile(values, 0.5)
        }

        function percentile(values, p) {
            if (values.length === 0)
                return 0
            const sorted = values.slice().sort((a, b) => a - b)
            return sorted[Math.min(sorted.length - 1, Math.floor(p * sorted.length))]
        }
    }
}
