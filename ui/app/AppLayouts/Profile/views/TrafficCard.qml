import QtQuick
import QtQuick.Layouts

import StatusQ.Core.Theme

//! A card of stacked content: tinted, or outlined when it has no tint.
Rectangle {
    default property alias content: cardColumn.data
    property color tint: "transparent"

    implicitHeight: cardColumn.implicitHeight + 16
    radius: Theme.radius
    color: tint
    border.width: tint.a === 0 ? 1 : 0
    border.color: Theme.palette.baseColor2

    ColumnLayout {
        id: cardColumn
        anchors.fill: parent
        anchors.margins: 8
        spacing: 2
    }
}
