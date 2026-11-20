import QtQuick

import StatusQ.Core

/// One memory release pass once dropped UI is gone: 2 s after a request in
/// the app (a burst coalesces), or synchronously on the way to the background
/// (SystemUtils.enteringBackground, emitted after every Qt.application.state
/// handler, so what drops there may be deleted at once), as Android stops the
/// event loop right after.
QtObject {
    id: root

    /// Handed to SystemUtils.releaseMemory: its engine is trimmed.
    required property var releaseContext

    /// Suspended or Hidden: sections drop on the way there. Set once the way
    /// out has begun, cleared when the app is back in front (Inactive, a
    /// system sheet on top, is still in front).
    readonly property bool appInBackground: d.appInBackground

    /// The application state; Qt.application.state unless driven.
    property int appState: Qt.application.state

    /// A pass ran.
    signal released()

    /// A section's UI went: release what it held.
    function request() {
        if (d.appInBackground)
            d.backgroundPassDue = true
        else
            d.timer.restart()
    }

    onAppStateChanged: {
        if (root.appState === Qt.ApplicationActive || root.appState === Qt.ApplicationInactive)
            d.appInBackground = false
    }

    // A QtObject takes no children: the private state is a property.
    readonly property QtObject d: QtObject {
        property bool appInBackground: false
        property bool backgroundPassDue: false

        readonly property Timer timer: Timer {
            interval: 2000
            onTriggered: d.releaseNow()
        }

        // After every Qt.application.state handler: what drops here may be
        // deleted at once.
        readonly property Connections backgroundEntry: Connections {
            target: SystemUtils

            function onEnteringBackground() {
                // a pass still pending is covered by the one on the way out
                if (d.timer.running) {
                    d.timer.stop()
                    d.backgroundPassDue = true
                }
                d.appInBackground = true
                if (d.backgroundPassDue)
                    d.releaseNow()
            }
        }

        function releaseNow() {
            d.timer.stop()
            d.backgroundPassDue = false
            SystemUtils.releaseMemory(root.releaseContext)
            root.released()
        }
    }
}
