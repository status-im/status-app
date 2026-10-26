pragma Singleton

import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

import "HttpTrafficReport.js" as Report

//! How the traffic dashboards show bytes: sent is always the danger colour,
//! received the primary colour.
QtObject {
    readonly property color sentColor: Theme.palette.dangerColor1
    readonly property color receivedColor: Theme.palette.primaryColor1
    //! For share bars; the last one is for what is pooled as "other".
    readonly property var shareColors: [Theme.palette.miscColor2, Theme.palette.miscColor6,
                                        Theme.palette.miscColor3, Theme.palette.baseColor1]

    function formatBytes(bytes) {
        return LocaleUtils.formattedDataSize(bytes, Report.sizePrecision(bytes))
    }

    function formatRate(bytes, seconds) {
        const rate = Report.hourly(bytes, seconds)
        return rate < 0 ? qsTr("—/h") : qsTr("%1/h").arg(formatBytes(rate))
    }

    function sentText(bytes) {
        return Report.colored(qsTr("↑ %1").arg(formatBytes(bytes)), sentColor)
    }

    function receivedText(bytes) {
        return Report.colored(qsTr("↓ %1").arg(formatBytes(bytes)), receivedColor)
    }
}
