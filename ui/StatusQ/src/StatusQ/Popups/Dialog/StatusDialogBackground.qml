import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

Rectangle {
    id: root

    color: Theme.palette.statusModal.backgroundColor
    topLeftRadius: Theme.radius
    topRightRadius: Theme.radius
    bottomLeftRadius: Theme.radius
    bottomRightRadius: Theme.radius

    signal closeRequested()

    MouseArea { // eat every event behind the control
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onPressed: event => event.accepted = true
        onPressAndHold: event => event.accepted = true
        onWheel: wheel => wheel.accepted = true
    }

    // "Back" handler
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        cursorShape: undefined // fall thru
        onClicked: function(mouse) {
            if (mouse.button !== Qt.BackButton)
                return
            root.closeRequested()
        }
    }

    ContextMenu.onRequested: ;
}
