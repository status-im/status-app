import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import utils

Rectangle {
    id: root

    property alias payloadToDisplay: contentText.text

    border.width: 1
    border.color: Theme.palette.baseColor2
    color: "transparent"
    radius: 8

    implicitHeight: d.expanded ? contentText.implicitHeight + (2 * contentText.anchors.margins)
                               : Math.min(contentText.implicitHeight + (2 * contentText.anchors.margins), d.maxContentHeight)

    HoverHandler {
        id: hoverHandler
        target: root
    }

    StatusBaseText {
        id: contentText
        objectName: "textContent"

        anchors.fill: parent
        anchors.margins: 20

        font.pixelSize: Theme.additionalTextSize
        lineHeightMode: Text.FixedHeight
        lineHeight: 18

        wrapMode: Text.Wrap

        layer.enabled: !d.expanded && d.canExpand
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
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0 }
                    GradientStop { position: (root.height - 60) / root.height }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }
    }

    StatusFlatButton {
        objectName: "expandButton"
        anchors.top: parent.top
        anchors.topMargin: 4
        anchors.right: parent.right
        anchors.rightMargin: 4
        icon.name: d.expanded ? "collapse" : "expand"
        icon.color: hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1
        hoverColor: "transparent"
        visible: d.canExpand && hoverHandler.hovered
        onClicked: {
            d.expanded = !d.expanded
        }
    }

    QtObject {
        id: d
        readonly property int maxContentHeight: 350
        property bool expanded: false
        readonly property bool canExpand: contentText.paintedHeight + (2 * contentText.anchors.margins) > maxContentHeight
    }
}
