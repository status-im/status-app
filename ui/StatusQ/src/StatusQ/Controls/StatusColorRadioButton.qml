pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

RadioButton {
    id: root

    property string radioButtonColor: ""
    property string selectionColor: StatusColors.white
    property int diameter: 44
    property int selectorDiameter: 16

    spacing: 0

    implicitWidth: 44
    implicitHeight: 44

    QtObject {
        id: d
        readonly property string yinYangColor: {
            if (root.radioButtonColor.toString().toUpperCase() === root.Theme.palette.customisationColors.yinYang.toString().toUpperCase()) {
                return root.Theme.palette.name === "light" ? "#FFFFFF" : "#09101C"
            }
            return ""

        }
    }

    indicator: Rectangle {
        implicitWidth: root.diameter
        implicitHeight: root.diameter
        radius: width/2
        color: radioButtonColor
        border.width: 1
        border.color: root.Theme.palette.directColor7

        Item {
            id: dualColor
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width/2
            height: parent.height
            clip: true
            Rectangle {
                width: parent.height
                height: parent.height
                radius: width/2
                color: d.yinYangColor
            }
            visible: !!d.yinYangColor
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.selectorDiameter
            height: root.selectorDiameter
            visible: root.checked
            radius: width/2
            color: selectionColor
            border.color: StatusColors.grey3
            border.width: 1
        }
    }

    HoverHandler {
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
    }
}

