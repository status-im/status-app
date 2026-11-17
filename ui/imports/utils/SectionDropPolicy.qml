import QtQuick

/// When a section gives its UI back (a Drop). While the section is not
/// shown, its UI is dropped after dropDelay, or at once on memory
/// pressure. A held section keeps its UI: the due drop is announced as
/// dropHeld() instead, and the delay starts over once the hold ends.
QtObject {
    id: root

    /// On screen: the section is current and the app is in front.
    required property bool shown
    /// Something in the UI must outlive a drop.
    property bool held: false

    property int dropDelay: 5 * 60 * 1000

    /// Whether the section's UI should exist.
    readonly property bool keepLoaded: shown || !d.dropped

    /// A drop came due while held: the owner sheds what it can.
    signal dropHeld()

    /// The UI is about to go: the last moment to read its state.
    signal dropping()

    function memoryPressure() {
        if (!root.shown && !d.dropped)
            d.drop()
    }

    onShownChanged: {
        if (root.shown) {
            d.timer.stop()
            d.dropped = false
            return
        }
        d.timer.restart()
    }

    onHeldChanged: {
        if (!root.held && !root.shown && !d.dropped)
            d.timer.restart()
    }

    readonly property QtObject d: QtObject {
        // Nothing is loaded before the section is first shown.
        property bool dropped: true

        readonly property Timer timer: Timer {
            interval: root.dropDelay
            onTriggered: d.drop()
        }

        function drop() {
            d.timer.stop()
            if (root.held) {
                root.dropHeld()
                return
            }
            root.dropping()
            d.dropped = true
        }
    }
}
