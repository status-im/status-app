import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

Rectangle {
    color: Theme.palette.statusModal.backgroundColor
    radius: Theme.radius

    MouseArea { // eat every event behind the control
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onPressed: event => event.accepted = true
        onPressAndHold: event => event.accepted = true
        onWheel: wheel => wheel.accepted = true
    }

    ContextMenu.onRequested: ;
}
