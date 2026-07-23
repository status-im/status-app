import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

import utils

// Mention pill drawn over a single mention object (U+FFFC) in ChatTextArea.
// Positions itself over `textArea` at the mention's document position.
Rectangle {
    id: root

    property string name
    property string pubKey
    property color backgroundColor: Theme.palette.baseColor2
    property color textColor: Theme.palette.primaryColor1

    property alias font: text.font
    property bool selected

    color: Utils.setColorAlpha(backgroundColor, selected ? 0.75 : 1)

    Text {
        id: text

        anchors.fill: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.name
        color: root.textColor
        elide: Text.ElideRight
    }

    ToolTip.visible: hover.hovered
    ToolTip.text: "pub key: " + pubKey

    HoverHandler { id: hover }
}
