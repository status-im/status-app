pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

StatusBaseText {
    id: root

    property double previousMessageTimestamp
    property double messageTimestamp

    readonly property int msInADay: 86400000
    readonly property int lastMessageInDays: previousMessageTimestamp / msInADay
    readonly property int currentMessageInDays: messageTimestamp / msInADay

    font.pixelSize: Theme.additionalTextSize
    color: Theme.palette.baseColor1
    horizontalAlignment: Text.AlignHCenter

    text: {
        if (messageTimestamp === 0)
            return ""

        if(previousMessageTimestamp > 0 && currentMessageInDays <= lastMessageInDays)
            return ""

        return LocaleUtils.formatDate(messageTimestamp)
    }
}
