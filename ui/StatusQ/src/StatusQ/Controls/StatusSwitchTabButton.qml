import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

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

    background: StatusBackgroundPanel {
        implicitWidth: 148
        implicitHeight: 36
        color: root.checked ? Theme.palette.statusSwitchTab.buttonBackgroundColor
                            : StatusColors.transparent
        shadowVisible: root.checked

        HoverHandler {
            cursorShape: hovered ? Qt.PointingHandCursor : undefined
        }
    }
}
