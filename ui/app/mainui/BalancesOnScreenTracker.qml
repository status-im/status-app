import QtQuick
import QtQuick.Window

import utils

// Tells whether balances are in front of the user, so that the backend can
// refresh them less often while they are not
QtObject {
    id: root

    required property int sectionType
    // On mobile the app is out of sight once it leaves the foreground. On
    // desktop the application state is no guide: it is inactive whenever
    // another window has the focus, with ours still in plain view beside it.
    // There only a minimized or hidden window is out of sight.
    required property bool isMobile
    required property int applicationState
    required property int windowVisibility
    // A popup that shows balances is open, whatever the section
    required property bool popupOpen

    // Milliseconds balances still count as on screen after they left it, so
    // that a short interruption such as a system dialog changes nothing
    property int leaveDelay: 3000

    readonly property bool windowShown: isMobile ? applicationState === Qt.ApplicationActive
                                                 : windowVisibility !== Window.Minimized &&
                                                   windowVisibility !== Window.Hidden
    readonly property bool inSight: windowShown &&
                                    (popupOpen ||
                                     sectionType === Constants.appSection.wallet ||
                                     sectionType === Constants.appSection.swap ||
                                     sectionType === Constants.appSection.market ||
                                     sectionType === Constants.appSection.browser ||
                                     sectionType === Constants.appSection.dApp)

    // inSight, kept for leaveDelay after it turns false
    property bool onScreen: inSight

    onInSightChanged: {
        if (inSight) {
            leaveTimer.stop()
            onScreen = true
        } else {
            leaveTimer.restart()
        }
    }

    readonly property Timer leaveTimer: Timer {
        interval: root.leaveDelay
        onTriggered: root.onScreen = root.inSight
    }
}
