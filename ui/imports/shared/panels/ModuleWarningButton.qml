import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

// Outlined button for ModuleWarning.actions
Button {
    id: root

    leftPadding: Theme.halfPadding
    rightPadding: Theme.halfPadding
    topPadding: 4
    bottomPadding: 4

    focusPolicy: SQUtils.Utils.isMobile ? Qt.NoFocus : Qt.TabFocus

    icon.width: 16
    icon.height: 16
    icon.color: Theme.palette.indirectColor1

    contentItem: Item {
        implicitWidth: row.implicitWidth
        implicitHeight: row.implicitHeight

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 4

            StatusIcon {
                Layout.preferredWidth: root.icon.width
                Layout.preferredHeight: root.icon.height
                visible: !!root.icon.name
                icon: root.icon.name
                color: root.icon.color
            }
            StatusBaseText {
                text: root.text
                font.pixelSize: Theme.additionalTextSize
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: Theme.palette.indirectColor1
            }
        }
    }

    background: Rectangle {
        radius: 4
        border.width: root.visualFocus ? 2 : 1
        border.color: root.visualFocus ? Theme.palette.indirectColor1 : Theme.palette.indirectColor3
        color: StatusColors.alphaColor(StatusColors.white, root.hovered ? 0.4 : 0.1)
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    Keys.onReturnPressed: click()
    Keys.onEnterPressed: click()
}
