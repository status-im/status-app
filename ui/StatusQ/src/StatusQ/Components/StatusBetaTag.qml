pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Core.Theme

Rectangle {
    id: root

    property color fgColor: Theme.palette.baseColor1
    property alias tooltipText: tip.text
    property alias cursorShape: hoverHandler.cursorShape
    property alias tooltipOrientation: tip.orientation

    readonly property bool hovered: hoverHandler.hovered

    implicitHeight: 20
    implicitWidth: 36
    radius: 4
    color: "transparent"
    border.width: 1
    border.color: root.fgColor

    StatusBaseText {
        font.pixelSize: Theme.fontSize(11)
        font.weight: Font.Medium
        color: root.fgColor
        anchors.centerIn: parent
        text: "Beta"
    }

    StatusToolTip {
        id: tip
        visible: hoverHandler.hovered && !!text
    }

    HoverHandler {
        id: hoverHandler
        enabled: root.visible
    }
}
