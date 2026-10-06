import QtQuick
import QtQuick.Controls
import QtQuick.Effects

import StatusQ.Core
import StatusQ.Core.Theme

Frame {
    id: root

    property bool dropShadow: true
    property alias cornerRadius: background.radius

    padding: Theme.bigPadding

    background: Rectangle {
        id: background
        border.width: 1
        border.color: Theme.palette.baseColor2
        radius: 20
        color: Theme.palette.background

        RectangularShadow {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            blur: 7
            offset.y: 4
            color: Theme.palette.dropShadow
            visible: root.dropShadow
        }
    }
}
