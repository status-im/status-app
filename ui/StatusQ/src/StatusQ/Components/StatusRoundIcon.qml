pragma ComponentBehavior: Bound

import QtQuick
import StatusQ.Core
import StatusQ.Core.Theme

Rectangle {
    id: root

    property StatusAssetSettings asset: StatusAssetSettings {
        width: 24
        height: 24
        rotation: 0
        color: root.Theme.palette.primaryColor1
        bgWidth: 40
        bgHeight: 40
        bgColor: root.Theme.palette.primaryColor3
        bgRadius: bgWidth / 2
    }

    color: asset.bgColor
    implicitWidth: asset.bgWidth
    implicitHeight: asset.bgHeight
    radius: asset.bgRadius
    border.width: asset.bgBorderWidth
    border.color: asset.bgBorderColor

    StatusIcon {
        id: statusIcon
        anchors.centerIn: parent

        width: root.asset.width
        height: root.asset.height

        color: root.asset.color
        icon: root.asset.name || root.asset.source
        rotation: root.asset.rotation
    }
}
