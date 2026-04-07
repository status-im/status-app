pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

MenuSeparator {
    id: root

    property string text

    background: Rectangle {
        color: Theme.palette.statusMenu.backgroundColor
    }

    contentItem: StatusBaseText {
        color: Theme.palette.baseColor1
        font.pixelSize: Theme.tertiaryTextFontSize
        text: root.text
    }
}
