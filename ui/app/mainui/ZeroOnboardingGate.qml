import QtQuick
import QtQml

import StatusQ

import utils

// Actions that reveal the profile's own addresses wait until the profile has a password
QtObject {
    id: root

    required property bool zeroOnboarded

    signal passwordRequired(string title, var onSuccess, var onCancel)

    function runWithProfilePassword(title: string, action, onCancel) : void {
        if (root.zeroOnboarded)
            root.passwordRequired(title, action, onCancel)
        else
            action()
    }

    readonly property Connections globalConnections: Connections {
        target: Global

        function onCopyOwnAddressRequested(address: string) {
            root.runWithProfilePassword(qsTr("Set password to copy address"), () => ClipboardUtils.setText(address), null)
        }
        function onOpenOwnAddressLinkRequested(link: string) {
            root.runWithProfilePassword("", () => Global.requestOpenLink(link), null)
        }
        function onPasswordRequiredFor(action, onCancel) {
            root.runWithProfilePassword("", action, onCancel)
        }
    }
}
