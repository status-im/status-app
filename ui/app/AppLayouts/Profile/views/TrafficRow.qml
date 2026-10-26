import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

//! What one consumer moved: name, rate, total, the split bar and a line of details.
ColumnLayout {
    id: root

    property string label
    property string rateText
    property string totalText
    property real sent
    property real received
    property real fullBytes: 1
    //! Styled text.
    property string details
    property bool monospace: false
    property bool chevron: false
    property color sentColor: TrafficFormat.sentColor
    property color receivedColor: TrafficFormat.receivedColor

    spacing: 3

    RowLayout {
        Layout.fillWidth: true
        StatusBaseText {
            objectName: "trafficRowLabel"
            Layout.fillWidth: true
            text: root.label
            textFormat: Text.PlainText
            font.family: root.monospace ? Fonts.monoFont.family : Fonts.baseFont.family
            font.pixelSize: root.monospace ? Theme.additionalTextSize : Theme.primaryTextFontSize
            font.weight: root.monospace ? Font.Normal : Font.Medium
            elide: root.monospace ? Text.ElideMiddle : Text.ElideRight
        }
        TrafficChip {
            text: root.rateText
            textColor: Theme.palette.baseColor1
        }
        StatusBaseText {
            text: root.totalText
            font.bold: true
        }
        StatusBaseText {
            visible: root.chevron
            text: "›"
            color: Theme.palette.baseColor1
        }
    }
    TrafficSplitBar {
        Layout.fillWidth: true
        sent: root.sent
        received: root.received
        fullBytes: root.fullBytes
        sentColor: root.sentColor
        receivedColor: root.receivedColor
    }
    StatusBaseText {
        objectName: "trafficRowDetails"
        Layout.fillWidth: true
        text: root.details
        textFormat: Text.StyledText
        font.pixelSize: Theme.tertiaryTextFontSize
        color: Theme.palette.baseColor1
        wrapMode: Text.WordWrap
    }
}
