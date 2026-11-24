import QtQuick

import StatusQ.Core.Utils

/// When a section gives its UI back (a Drop). A section the user left (not
/// current) is dropped after dropDelay, which runs only while the app is in
/// front, or at once when the app goes to the background (Android then stops
/// the event loop and freezes the process, so nothing could come due there).
/// Memory pressure in front drops it at once. The current section is never
/// dropped: it is on screen, under a system sheet, or what the user comes
/// back to. A held section keeps its UI: the due drop is announced as
/// dropHeld() instead, and the delay starts over once that hold ends. A hold
/// that ends before a drop came due leaves the running delay alone.
QObject {
    id: root

    /// On screen: the section is current and the app is in front.
    required property bool shown
    /// The section is the current one, whether the app is in front or not.
    property bool current: shown
    /// Something in the UI must outlive a drop.
    property bool held: false

    /// The app is in the background (Suspended or Hidden; Inactive, a system
    /// sheet on top, is still in front). Follow
    /// MemoryReleaseScheduler.appInBackground, so what drops on the way out is
    /// gone before its release pass.
    required property bool inBackground

    property int dropDelay: 5 * 60 * 1000

    /// Whether the section's UI should exist.
    readonly property bool keepLoaded: shown || !d.dropped

    /// The delay to a drop runs.
    readonly property bool dropPending: timer.running

    /// A drop came due while held: the owner sheds what it can.
    signal dropHeld()

    /// The UI is about to go: the last moment to read its state.
    signal dropping()

    /// Ignored in the background: what could go went on the way out, and
    /// pressure queued while frozen is handled on the way back, before the
    /// app is in front.
    function memoryPressure() {
        if (d.dropped || root.shown || root.current || root.inBackground)
            return
        d.drop()
    }

    onShownChanged: d.update()
    onCurrentChanged: d.update()
    onInBackgroundChanged: d.update()

    onHeldChanged: {
        if (!root.held && d.deferred && !root.current && !d.dropped && !root.inBackground) {
            d.deferred = false
            timer.restart()
        }
    }

    QtObject {
        id: d

        // Nothing is loaded before the section is first shown.
        property bool dropped: true
        // A drop came due while held.
        property bool deferred: false

        function update() {
            if (root.shown)
                d.dropped = false
            if (root.current) {
                d.deferred = false
                timer.stop()
                return
            }
            if (root.inBackground) {
                timer.stop()
                if (!d.dropped && !d.deferred)
                    d.drop()
                return
            }
            if (!d.dropped && !timer.running)
                timer.restart()
        }

        function drop() {
            timer.stop()
            if (root.held) {
                d.deferred = true
                root.dropHeld()
                return
            }
            root.dropping()
            d.dropped = true
        }
    }

    Timer {
        id: timer

        interval: root.dropDelay
        onTriggered: d.drop()
    }
}
