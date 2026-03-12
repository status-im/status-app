import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

Rectangle {
    id: root

    property int value

    implicitHeight: root.value > 0 ? 18 + root.border.width
                                   : 10 + root.border.width
    implicitWidth: {
        if (root.value > 99) {
            return 28 + root.border.width
        }
        if (root.value > 9) {
            return 26 + root.border.width
        }
        if (root.value > 0) {
            return 18 + root.border.width
        }
        return 10 + root.border.width
    }
    radius: height / 2
    color: Theme.palette.primaryColor1

    StatusBaseText {
        id: badgeText
        visible: root.value > 0
        font.pixelSize: Theme.asideTextFontSize
        font.weight: Font.Medium
        color: Theme.palette.statusBadge.foregroundColor

        anchors.fill: parent

        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter

        text: {
            if (root.value > 99) {
                return qsTr("99+")
            }
            return root.value
        }
    }
}
