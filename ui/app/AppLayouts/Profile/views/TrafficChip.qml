import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

//! A small rounded label, e.g. a per-hour rate next to a total.
Rectangle {
    id: root

    property alias text: chipText.text
    property color textColor: Theme.palette.directColor1

    implicitWidth: chipText.implicitWidth + 12
    implicitHeight: chipText.implicitHeight + 4
    radius: height / 2
    color: Theme.palette.baseColor2

    StatusBaseText {
        id: chipText
        anchors.centerIn: parent
        font.pixelSize: Theme.tertiaryTextFontSize
        color: root.textColor
    }
}
