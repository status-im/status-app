import QtQuick

import MobileUI

// StatusSecondaryActionHandler.qml
// Detects platform-appropriate secondary action gestures:
// right-click / stylus tap on desktop, long-press on touch screens.
// Emits triggered(point position, int source) — source is TriggerSource.RightClick or TriggerSource.LongPress.
Item {
    id: root
    anchors.fill: parent

    enum TriggerSource {
        RightClick,
        LongPress
    }

    signal triggered(point position, int source)

    // Right-click / stylus: desktop and tablet with mouse.
    TapHandler {
        acceptedButtons: Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        onTapped: (eventPoint, button) => root.triggered(eventPoint.position, StatusSecondaryActionHandler.RightClick)
    }

    // Long-press: touch screens only.
    TapHandler {
        acceptedDevices: PointerDevice.TouchScreen
        onLongPressed: {
            MobileUI.vibrate() // no-op on non-mobile platforms (e.g. laptop touch screens)
            root.triggered(point.position, StatusSecondaryActionHandler.LongPress)
        }
    }
}
