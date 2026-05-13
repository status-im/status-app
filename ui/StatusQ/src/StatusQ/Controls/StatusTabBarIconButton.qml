import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

Item {
    id: root

    property StatusAssetSettings icon: StatusAssetSettings {
        width: 28
        height: 28
        name: ""
    }

    property bool highlighted: false

    signal clicked(var mouse)

    implicitWidth: 44
    implicitHeight: 44

    StatusMouseArea {
        id: sensor
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        anchors.fill: parent
        hoverEnabled: true
        onClicked: function (mouse) {
            root.clicked(mouse)
        }

        StatusIcon {
            id: statusIcon
            width: root.icon.width
            height: root.icon.height
            icon: root.icon.name
            color: root.highlighted || sensor.containsMouse ? Theme.palette.primaryColor1 : Theme.palette.baseColor1
            anchors.centerIn: parent
        }

        Rectangle {
            visible: root.highlighted || sensor.containsMouse
            width: statusIcon.width
            anchors.horizontalCenter: parent.horizontalCenter
            height: 2
            radius: 1
            color: Theme.palette.primaryColor1
            anchors.bottom: parent.bottom
        }
    }
}

