import QtQuick

import utils

/// The Browser's Drop (see CONTEXT: Drop, Keep-alive reason), on top of
/// SectionDropPolicy. Left for another section, it goes after a delay while
/// the app is in front (dropGrace without a live page, so a passing state
/// flicker is no exit, else dropDelay), or at once when the app goes to the
/// background. In focus it stays through the background. Memory pressure
/// drops it at once when not on screen; a background trim only when it is not
/// the current section. A Keep-alive reason holds the layout: only the idle Web Views are
/// dropped, and the delay starts over once the last reason ends.
QtObject {
    id: root

    /// On screen: the section is current and the app is in front.
    required property bool shown
    /// The Browser is the current section, whether the app is in front or not.
    property bool current: shown
    /// The app is in the background (see SectionDropPolicy.inBackground).
    property bool inBackground: Qt.application.state === Qt.ApplicationSuspended
                                || Qt.application.state === Qt.ApplicationHidden
    /// A Tab has a loaded Web View with a page in it.
    required property bool hasLivePage
    /// A Web View holds a Keep-alive reason.
    required property bool keepAlive

    property int dropDelay: 5 * 60 * 1000
    property int dropGrace: 3000

    /// Off: no Drop at all, the layout stays from the first show on.
    property bool enabled: true

    /// Whether the Browser layout should exist.
    readonly property bool keepLoaded: root.enabled ? policy.keepLoaded : d.visited

    /// Drop every Web View that holds no Keep-alive reason; the layout stays.
    signal dropIdleViewsRequested()

    /// The layout is about to go: the last moment to read its Tabs.
    signal dropping()

    /// critical: real pressure; else a background trim (see SectionDropPolicy).
    function memoryPressure(critical) {
        if (root.enabled)
            policy.memoryPressure(critical)
    }

    readonly property QtObject d: QtObject {
        // What there was when the Browser left the screen, kept while it is away.
        property bool liveOnExit: false
        property bool visited: false

        readonly property Binding visitTracker: Binding {
            target: root.d
            property: "visited"
            value: true
            when: root.shown
            restoreMode: Binding.RestoreNone
        }

        readonly property Binding liveTracker: Binding {
            target: root.d
            property: "liveOnExit"
            value: root.hasLivePage || root.keepAlive
            when: root.shown
            restoreMode: Binding.RestoreNone
        }
    }

    readonly property SectionDropPolicy policy: SectionDropPolicy {
        shown: !root.enabled || root.shown
        current: !root.enabled || root.current
        inBackground: root.enabled && root.inBackground
        held: root.keepAlive
        dropDelay: root.d.liveOnExit ? root.dropDelay : root.dropGrace

        onDropHeld: root.dropIdleViewsRequested()
        onDropping: root.dropping()
    }
}
