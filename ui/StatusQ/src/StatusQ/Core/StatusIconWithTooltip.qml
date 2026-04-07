pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Controls

StatusIcon {
    id: root

    property string tooltipText

    StatusMouseArea {
        id: tooltipSensor
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
    }

    StatusToolTip {
        visible: tooltipSensor.containsMouse && !!text
        text: root.tooltipText
    }
}
