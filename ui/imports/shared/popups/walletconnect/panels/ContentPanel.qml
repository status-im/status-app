import QtQuick
import QtQuick.Layouts

import StatusQ.Components
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

        // Collapsed: the bottom 60 px of the panel fade out, computed by the
        // shader on the text's layer, with no second layer for a mask
        layer.enabled: !d.expanded && d.canExpand
        layer.effect: StatusEdgeFadeEffect {
            bottomFade: 60 * contentText.height / root.height
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
