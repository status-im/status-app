pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects

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
    layer.effect: MultiEffect {
        maskEnabled: true
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        maskSource: Rectangle {
            parent: root
            layer.enabled: true
            visible: false
            width: root.width
            height: root.height
            radius: background.radius
        }
    }
}
