import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

//! A headline figure: caption, total in the accent colour and its rate. Content
//! added by the user goes below.
TrafficCard {
    id: root

    property string label
    property string totalText
    property string rateText
    property color accent
    property string totalObjectName
    property string rateObjectName

    Layout.fillWidth: true

    TrafficCaption {
        text: root.label
    }
    StatusBaseText {
        objectName: root.totalObjectName
        text: root.totalText
        font.pixelSize: 22
        font.bold: true
        color: root.accent
    }
    TrafficChip {
        objectName: root.rateObjectName
        text: root.rateText
        textColor: Theme.palette.baseColor1
    }
}
