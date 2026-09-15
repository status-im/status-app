import QtQuick

// Benchmark instrumentation shared by the ChatLoader and CommunityChatLoader
// pages, so both measure the message view the same way.
//
// Positional arguments (storybook's CLI parser rejects unknown --options):
//   census    keep logging built message delegates and the row count of the
//             model the view sees
//   scrollup  drag the view a screen towards history per census tick for the
//             first half of the census, then back towards the newest messages
//   rerefresh re-run the page's Refresh once the first load has settled, so the
//             warm path is measured as well as the fresh one
Item {
    id: root

    // Instrumentation only: the pages that host it are SplitViews, which would
    // otherwise give it a pane of its own
    visible: false

    // Root of the loaded section harness to search for the message view
    property Item harnessItem: null

    // Prefix for every log line, so runs of the two pages stay distinguishable
    property string label: ""

    // Set by the page right before it activates the harness
    property double loadStartTime: 0

    readonly property bool censusMode: Qt.application.arguments.indexOf("census") >= 0
    readonly property bool scrollUpMode: Qt.application.arguments.indexOf("scrollup") >= 0

    readonly property alias view: d.messageView

    // Milliseconds the message view took to show its first built delegate,
    // -1 while it has not
    property int messagesShownMs: -1

    signal messagesShown(int ms)

    // Emitted when the page should re-run its Refresh (see "rerefresh")
    signal refreshRequested()

    readonly property bool rerefreshMode: Qt.application.arguments.indexOf("rerefresh") >= 0

    // Which load the numbers being logged belong to
    property string pass: "fresh"

    // Highest number of message delegates built at any sampled moment since
    // the load started — a view that materializes the history and then settles
    // still made the user watch it happen, so the resting count alone lies.
    property int peakDelegates: 0

    function restart() {
        d.messageView = null
        root.messagesShownMs = -1
        root.peakDelegates = 0
        d.viewForSampling = null
        d.trajectory = []
        censusTimer.stop()
        peakProbe.restart()
        messagesProbe.restart()
    }

    // Counts built message delegates without descending into them, so the
    // traversal cost stays proportional to the container tree + delegate count.
    function countDelegates(obj) {
        if (!obj)
            return 0
        if (obj.objectName === "chatMessageViewDelegate")
            return 1
        let n = 0
        const kids = obj.children || []
        for (let i = 0; i < kids.length; ++i)
            n += countDelegates(kids[i])
        return n
    }

    function findByName(obj, name) {
        if (!obj)
            return null
        if (obj.objectName === name)
            return obj
        const kids = obj.children || []
        for (let i = 0; i < kids.length; ++i) {
            const r = findByName(kids[i], name)
            if (r)
                return r
        }
        return null
    }

    QtObject {
        id: d

        property Item messageView: null

        // The view is looked up ignoring visibility, so delegates built while
        // the section is still incubating behind its skeleton are counted too
        property Item viewForSampling: null

        property var trajectory: []
    }

    Timer {
        id: peakProbe

        interval: 50
        repeat: true
        running: false

        onTriggered: {
            if (!root.harnessItem)
                return
            if (!d.viewForSampling) {
                d.viewForSampling = root.findByName(root.harnessItem, "chatLogView")
                if (d.viewForSampling)
                    console.info(root.label, "view found after",
                                 Date.now() - root.loadStartTime, "ms")
            }
            if (!d.viewForSampling)
                return
            root.peakDelegates = Math.max(root.peakDelegates,
                                          root.countDelegates(d.viewForSampling))

            // Concurrent delegates stay low even while a view streams the whole
            // history past the viewport, so also record where the view is
            // looking: a traversal shows up as contentY sweeping the content.
            const y = Math.round(d.viewForSampling.contentY)
            if (d.trajectory.length === 0 || d.trajectory[d.trajectory.length - 1] !== y)
                d.trajectory.push(y)
            if (d.trajectory.length > 400)
                d.trajectory.shift()
        }
    }

    // Total distance the view travelled while loading; a bottom-anchored open
    // should be a single jump, not a sweep across the history.
    function reportTrajectory(phase) {
        const t = d.trajectory
        if (t.length === 0) {
            console.info(root.label, "TRAJECTORY", phase, "none")
            return
        }
        let travelled = 0
        for (let i = 1; i < t.length; ++i)
            travelled += Math.abs(t[i] - t[i - 1])
        console.info(root.label, "TRAJECTORY " + phase + " samples=" + t.length,
                     "min=" + Math.min(...t), "max=" + Math.max(...t),
                     "travelled=" + travelled)
        console.info(root.label, "TRAJECTORY path", JSON.stringify(t.slice(0, 60)))
    }

    // READY alone does not mean the user sees messages (a state may build them
    // after the section is Ready, behind a skeleton). Poll until the message
    // view has at least one built, visible delegate and no covering skeleton.
    Timer {
        id: messagesProbe

        interval: 16
        repeat: true

        onTriggered: {
            if (!root.harnessItem)
                return
            const skeleton = root.findByName(root.harnessItem, "chatMessagesSkeleton")
            if (skeleton && skeleton.visible)
                return
            if (!d.messageView)
                d.messageView = root.findByName(root.harnessItem, "chatLogView")
            if (!d.messageView || !d.messageView.visible || !d.messageView.contentItem)
                return

            const delegate = root.findByName(d.messageView.contentItem, "chatMessageViewDelegate")
            if (!delegate || !delegate.visible)
                return

            const ms = Date.now() - root.loadStartTime
            root.messagesShownMs = ms
            console.info(root.label, "MESSAGES", root.pass, "in", ms, "ms")
            console.info(root.label, "model rows:", d.messageView.count,
                         "peak delegates since load:", root.peakDelegates)
            running = false
            root.reportTrajectory("to-first-paint")
            root.messagesShown(ms)

            if (root.censusMode) {
                censusTimer.ticks = 0
                censusTimer.restart()
            }
            if (root.rerefreshMode && root.pass === "fresh")
                rerefreshTimer.restart()
        }
    }

    Timer {
        id: rerefreshTimer

        interval: 2000
        onTriggered: {
            root.pass = "refresh"
            root.refreshRequested()
        }
    }

    // The peak matters as much as the resting count: a view that materializes
    // the history and then settles still made the user watch it happen.
    Timer {
        id: censusTimer

        property int ticks: 0
        property int peakDelegates: 0

        interval: 500
        repeat: true

        onTriggered: {
            const view = d.messageView
            if (!view)
                return
            ++ticks
            if (root.scrollUpMode)
                view.contentY += view.height * 0.9 * (ticks > 20 ? 1 : -1)

            // One report covering load plus the settle window: a bottom-anchored
            // open travels once, a traversal keeps sweeping
            if (ticks === 4)
                root.reportTrajectory("through-settle")

            const built = root.countDelegates(view)
            peakDelegates = Math.max(peakDelegates, built)
            console.info(root.label + " CENSUS t=" + (ticks * interval)
                         + " delegates=" + built
                         + " peak=" + peakDelegates
                         + " rows=" + view.count
                         + " contentHeight=" + Math.round(view.contentHeight)
                         + " contentY=" + Math.round(view.contentY))
        }
    }
}
