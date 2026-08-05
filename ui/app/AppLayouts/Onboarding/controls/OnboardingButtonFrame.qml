pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Core.Theme

Frame {
    id: root

    padding: 0

    background: Rectangle {
        id: background
        border.width: 1
        border.color: Theme.palette.baseColor2
        radius: 12
        color: Theme.palette.background
    }

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: background.radius
            visible: false
        }
    }
}
