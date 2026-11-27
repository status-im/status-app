import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme

import utils

StatusIcon {
    id: root

    required property string textToCopy
    // The copy waits until the profile has a password
    property bool revealNeedsPassword: false

    readonly property bool hovered: mouseArea.containsMouse

    icon: "copy"
    color: mouseArea.containsMouse? Theme.palette.primaryColor1 : Theme.palette.baseColor1

    function reset() {
        root.icon = "copy"
        root.color = Qt.binding(function(){ return mouseArea.containsMouse? Theme.palette.primaryColor1 : Theme.palette.baseColor1 })
    }

    StatusMouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.revealNeedsPassword) {
                Global.copyOwnAddressRequested(root.textToCopy)
                return
            }
            ClipboardUtils.setText(root.textToCopy)
            root.icon = "tiny/checkmark"
            root.color = Theme.palette.successColor1

            Backpressure.debounce(root, 1500, function () {
                root.reset()
            })()
        }
    }
}
