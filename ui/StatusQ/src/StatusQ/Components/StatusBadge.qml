import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

Rectangle {
    id: statusBadge

    property int value

    implicitHeight: statusBadge.value > 0 ? 18 + statusBadge.border.width : 10 + statusBadge.border.width
    implicitWidth: {
        if (statusBadge.value > 99) {
            return 28 + statusBadge.border.width
        }
        if (statusBadge.value > 9) {
            return 26 + statusBadge.border.width
        }
        if (statusBadge.value > 0) {
            return 18 + statusBadge.border.width
        }
        return 10 + statusBadge.border.width
    }
    radius: height / 2
    color: Theme.palette.primaryColor1

    StatusBaseText {
        id: value
        visible: statusBadge.value > 0
        font.pixelSize: Theme.asideTextFontSize
        font.weight: Font.Medium
        color: Theme.palette.statusBadge.foregroundColor
        anchors.centerIn: parent
        anchors.verticalCenterOffset: statusBadge.border.width/4
        anchors.horizontalCenterOffset: statusBadge.border.width/4
        text: {
            if (statusBadge.value > 99) {
                return qsTr("99+");
            }
            return statusBadge.value;
        }
    }
}
