import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

import "HttpTrafficReport.js" as Report

//! The key to the dashboard's colours and figures, with a note of its own.
StatusBaseText {
    property string note

    Layout.fillWidth: true
    text: [qsTr("%1 sent · %2 received · bold = total since start · chip = per hour")
               .arg(Report.colored(qsTr("↑"), TrafficFormat.sentColor))
               .arg(Report.colored(qsTr("↓"), TrafficFormat.receivedColor)),
           note].filter(part => part !== "").join(" · ")
    textFormat: Text.StyledText
    font.pixelSize: Theme.tertiaryTextFontSize
    color: Theme.palette.baseColor1
    wrapMode: Text.WordWrap
}
