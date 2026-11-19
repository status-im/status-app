import QtQuick

import utils

/// The Browser's Drop (see CONTEXT: Drop, Keep-alive reason), on top of
/// SectionDropPolicy. Without a live page the layout goes after dropGrace, so
/// a passing state flicker is no exit; else after dropDelay or on memory
/// pressure. A Keep-alive reason holds the layout: only the idle Web Views are
/// dropped, and the delay starts over once the last reason ends.
QtObject {
    id: root

    /// On screen: the section is current and the app is in front.
    required property bool shown
    /// A Tab has a loaded Web View with a page in it.
    required property bool hasLivePage
    /// A Web View holds a Keep-alive reason.
    required property bool keepAlive

    property int dropDelay: 5 * 60 * 1000
    property int dropGrace: 3000

    /// Off: no Drop at all, the layout stays from the first show on (desktop).
    property bool enabled: true

    /// Whether the Browser layout should exist.
    readonly property bool keepLoaded: root.enabled ? policy.keepLoaded : d.visited

    /// Drop every Web View that holds no Keep-alive reason; the layout stays.
    signal dropIdleViewsRequested()

    /// The layout is about to go: the last moment to read its Tabs.
    signal dropping()

    function memoryPressure() {
        if (root.enabled)
            policy.memoryPressure()
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
        held: root.keepAlive
        dropDelay: root.d.liveOnExit ? root.dropDelay : root.dropGrace

        onDropHeld: root.dropIdleViewsRequested()
        onDropping: root.dropping()
    }
}
