import QtQuick

import StatusQ.Core
import StatusQ.Core.Utils

/// One memory release pass once dropped UI is gone: releaseDelay after a
/// request in the app (a burst coalesces), or synchronously on the way to the
/// background (SystemUtils.enteringBackground), as Android stops the event
/// loop right after. Drops due there must follow appInBackground, which turns
/// true inside that handler, so they are gone before the pass.
QObject {
    id: root

    /// Handed to SystemUtils.releaseMemory: its engine is trimmed.
    required property var releaseContext

    /// Suspended or Hidden: sections drop on the way there. Set once the way
    /// out has begun, cleared when the app is back in front (Inactive, a
    /// system sheet on top, is still in front).
    readonly property bool appInBackground: d.appInBackground

    /// The application state; Qt.application.state unless driven.
    property int appState: Qt.application.state

    property int releaseDelay: 2000

    /// A pass in the app is scheduled.
    readonly property bool passPending: timer.running

    /// A pass ran.
    signal released()

    /// A section's UI went: release what it held.
    function request() {
        if (d.appInBackground)
            d.backgroundPassDue = true
        else
            timer.restart()
    }

    onAppStateChanged: {
        if (root.appState !== Qt.ApplicationActive && root.appState !== Qt.ApplicationInactive)
            return
        d.appInBackground = false
        // a request made in the background got no pass on the way out
        if (d.backgroundPassDue) {
            d.backgroundPassDue = false
            timer.restart()
        }
    }

    QtObject {
        id: d

        property bool appInBackground: false
        property bool backgroundPassDue: false

        // flushDeletes: the event loop stops right after, so what dropped
        // there is deleted now rather than at return
        function releaseNow(flushDeletes) {
            timer.stop()
            d.backgroundPassDue = false
            SystemUtils.releaseMemory(root.releaseContext, flushDeletes)
            root.released()
        }
    }

    Timer {
        id: timer

        interval: root.releaseDelay
        onTriggered: d.releaseNow(false)
    }

    Connections {
        target: SystemUtils

        function onEnteringBackground() {
            // a pass still pending is covered by the one on the way out
            if (timer.running) {
                timer.stop()
                d.backgroundPassDue = true
            }
            d.appInBackground = true
            if (d.backgroundPassDue)
                d.releaseNow(true)
        }
    }
}
