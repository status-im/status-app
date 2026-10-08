import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Effects

import StatusQ.Core.Theme

import utils
import shared
import shared.controls


Control {
    id: root

    property bool leftTail: true
    property color backgroundColor: Theme.palette.background
    property color borderColor: Theme.palette.border
    property bool dashedBorder: false
    property bool dropShadow: false
    property real borderWidth: 1

    readonly property Component clippingEffect: CalloutOpacityMask {
        width: parent.width
        height: parent.height
        leftTail: root.leftTail
    }

    background: ShapeRectangle {
        path.fillColor: root.backgroundColor
        path.strokeColor: root.borderColor
        path.strokeWidth: root.borderWidth
        path.strokeStyle: root.dashedBorder ? ShapePath.DashLine : ShapePath.SolidLine
        radius: Theme.radius * 2
        leftBottomRadius: root.leftTail ? Theme.radius / 2 : Theme.radius * 2
        rightBottomRadius: root.leftTail ? Theme.radius * 2 : Theme.radius / 2
        RectangularShadow {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            bottomLeftRadius: parent.leftBottomRadius
            bottomRightRadius: parent.rightBottomRadius
            blur: 8
            offset.y: 3
            color: Theme.palette.dropShadow
            visible: root.dropShadow
        }
    }
}
