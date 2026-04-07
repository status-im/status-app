pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme

TabButton {
    id: root

    font.pixelSize: Theme.primaryTextFontSize

    contentItem: RowLayout {
        spacing: Theme.smallPadding

        StatusBaseText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignCenter
            horizontalAlignment: Text.AlignHCenter
            text: root.text
            color: root.checked ?
                       Theme.palette.statusSwitchTab.selectedTextColor :
                       Theme.palette.statusSwitchTab.textColor
            font.weight: Font.Medium
            font.pixelSize: root.font.pixelSize
            elide: Text.ElideRight
        }
    }

    background: Rectangle {
        implicitWidth: 148
        implicitHeight: 36
        color: root.checked ? Theme.palette.statusSwitchTab.buttonBackgroundColor
                            : "transparent"
        radius: Theme.radius
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 0
            radius: 10
            samples: 25
            spread: 0
            color: Theme.palette.dropShadow
        }

        HoverHandler {
            cursorShape: hovered ? Qt.PointingHandCursor : undefined
        }
    }
}
