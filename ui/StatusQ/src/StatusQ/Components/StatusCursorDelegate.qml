pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core.Theme

Rectangle {
    id: root

    required property bool cursorVisible

    color: Theme.palette.primaryColor1
    implicitWidth: 2
    implicitHeight: 22
    radius: 1
    visible: cursorVisible

    SequentialAnimation on visible {
        loops: Animation.Infinite
        running: root.cursorVisible
        PropertyAnimation { to: false; duration: Qt.styleHints.cursorFlashTime / 2 }
        PropertyAnimation { to: true; duration: Qt.styleHints.cursorFlashTime / 2 }
    }
}
