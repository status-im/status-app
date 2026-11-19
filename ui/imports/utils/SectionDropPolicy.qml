import QtQuick

/// When a section gives its UI back (a Drop). A section the user left (not
/// current) is dropped after dropDelay, which runs only while the app is in
/// front, or at once when the app goes to the background (Android then stops
/// the event loop and freezes the process, so nothing could come due there).
/// On memory pressure every section not on screen is dropped at once, the
/// current one too when the app is in the background; a background trim
/// (no pressure) drops only the sections the user left. A held section keeps
/// its UI: the due drop is announced as dropHeld() instead, and the delay
/// starts over once that hold ends. A hold that ends before a drop came due
/// leaves the running delay alone.
QtObject {
    id: root

    /// On screen: the section is current and the app is in front.
    required property bool shown
    /// The section is the current one, whether the app is in front or not.
    property bool current: shown
    /// Something in the UI must outlive a drop.
    property bool held: false

    property int dropDelay: 5 * 60 * 1000

    /// The app is in the background (Suspended or Hidden; Inactive, a system
    /// sheet on top, is still in front).
    property bool inBackground: Qt.application.state === Qt.ApplicationSuspended
                                || Qt.application.state === Qt.ApplicationHidden

    /// Whether the section's UI should exist.
    readonly property bool keepLoaded: shown || !d.dropped

    /// A drop came due while held: the owner sheds what it can.
    signal dropHeld()

    /// The UI is about to go: the last moment to read its state.
    signal dropping()

    /// critical: real pressure, which spares only what is on screen; else a
    /// background trim, which spares the current section too.
    function memoryPressure(critical) {
        if (d.dropped || root.shown || (!critical && root.current))
            return
        d.drop()
    }

    onShownChanged: d.update()
    onCurrentChanged: d.update()
    onInBackgroundChanged: d.update()

    onHeldChanged: {
        if (!root.held && d.deferred && !root.current && !d.dropped && !root.inBackground) {
            d.deferred = false
            d.timer.restart()
        }
    }

    // A QtObject takes no children: the private state is a property.
    readonly property QtObject d: QtObject {
        // Nothing is loaded before the section is first shown.
        property bool dropped: true
        // A drop came due while held.
        property bool deferred: false

        readonly property Timer timer: Timer {
            interval: root.dropDelay
            onTriggered: d.drop()
        }

        function update() {
            if (root.shown)
                d.dropped = false
            if (root.current) {
                d.deferred = false
                d.timer.stop()
                return
            }
            if (root.inBackground) {
                d.timer.stop()
                if (!d.dropped && !d.deferred)
                    d.drop()
                return
            }
            if (!d.dropped && !d.timer.running)
                d.timer.restart()
        }

        function drop() {
            d.timer.stop()
            if (root.held) {
                d.deferred = true
                root.dropHeld()
                return
            }
            root.dropping()
            d.dropped = true
        }
    }
}
