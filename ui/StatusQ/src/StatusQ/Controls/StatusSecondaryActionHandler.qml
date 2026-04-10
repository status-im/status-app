import QtQuick

import MobileUI

// StatusSecondaryActionHandler.qml
// Detects platform-appropriate secondary action gestures:
// right-click / stylus tap on desktop, long-press on touch screens.
// Emits triggered() — the parent decides what to do.
Item {
    anchors.fill: parent

    signal triggered()

    // Right-click / stylus: desktop and tablet with mouse.
    TapHandler {
        acceptedButtons: Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        onTapped: triggered()
    }

    // Long-press: touch screens only.
    TapHandler {
        acceptedDevices: PointerDevice.TouchScreen
        onLongPressed: {
            MobileUI.vibrate() // no-op on non-mobile platforms (e.g. laptop touch screens)
            triggered()
        }
    }
}
