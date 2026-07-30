import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

// Mention pill drawn over a single mention object (U+FFFC) in ChatTextArea.
// Positions itself over `textArea` at the mention's document position.
Rectangle {
    id: root

    property string name
    property string pubKey
    property color backgroundColor: Theme.palette.mentionColor2
    property color textColor: Theme.palette.mentionColor1

    property alias font: text.font

    radius: 3
    color: backgroundColor

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
