import QtQuick
import QtQuick.Effects

import StatusQ.Core.Theme

Rectangle {
    id: root

    property bool shadowVisible: true
    property color shadowColor: Theme.palette.dropShadow3

    color: Theme.palette.background
    radius: Theme.radius

    RectangularShadow {
        anchors.fill: parent
        z: parent.z - 1
        topLeftRadius: parent.topLeftRadius
        topRightRadius: parent.topRightRadius
        bottomLeftRadius: parent.bottomLeftRadius
        bottomRightRadius: parent.bottomRightRadius
        color: root.shadowColor
        visible: root.shadowVisible
    }
}
