import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

RowLayout {
    id: root

    required property string icon
    required property string text

    height: d.iconSize
    spacing: Theme.smallPadding

    QtObject {
        id: d

        readonly property int iconSize: 20
        readonly property color iconColor: Theme.palette.baseColor1
    }


    StatusIcon {
        icon: root.icon
        width: d.iconSize
        height: d.iconSize
        color: d.iconColor
        Layout.leftMargin: 6
    }

    StatusBaseText {
        text: root.text
        font.pixelSize: Theme.secondaryTextFontSize
        Layout.fillWidth: true
    }
}