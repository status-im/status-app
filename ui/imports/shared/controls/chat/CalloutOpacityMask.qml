import QtQuick
import QtQuick.Effects

import StatusQ.Core.Theme

MultiEffect {
    id: root

    property bool leftTail: true
    readonly property real smallCorner: Theme.radius / 2
    readonly property real bigCorner: Theme.radius * 2

    maskEnabled: true
    maskThresholdMin: 0.5
    maskSpreadAtMin: 1.0

    maskSource: Rectangle {
        parent: root.parent

        width: root.width
        height: root.height
        visible: false
        layer.enabled: true

        topLeftRadius: root.bigCorner
        topRightRadius: root.bigCorner
        bottomLeftRadius: root.leftTail ? root.smallCorner : root.bigCorner
        bottomRightRadius: root.leftTail ? root.bigCorner : root.smallCorner
    }
}
