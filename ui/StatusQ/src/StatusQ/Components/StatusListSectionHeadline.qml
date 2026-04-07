pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

Item {
    implicitHeight: 34
    implicitWidth: 176

    property alias text: label.text

    StatusBaseText {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        anchors.leftMargin: 16
        id: label
        font.pixelSize: Theme.primaryTextFontSize
        color: Theme.palette.baseColor1
    }
}
