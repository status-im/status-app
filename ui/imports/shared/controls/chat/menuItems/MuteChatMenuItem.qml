import QtQuick
import QtQuick.Controls

import utils

import StatusQ.Popups

StatusMenu {
    property bool isCommunityChat: false

    signal muteTriggered(int interval)

    title: isCommunityChat ? qsTr("Mute Channel") : qsTr("Mute Chat")

    assetSettings.name: "notification-muted"

    StatusAction {
        objectName: "muteChatMenu_for15Mins"
        text: qsTr("For 15 mins")
        onTriggered: muteTriggered(Constants.MutingVariations.For15min)
    }

    StatusAction {
        objectName: "muteChatMenu_for1Hour"
        text: qsTr("For 1 hour")
        onTriggered: muteTriggered(Constants.MutingVariations.For1hr)
    }

    StatusAction {
        objectName: "muteChatMenu_for8Hours"
        text: qsTr("For 8 hours")
        onTriggered: muteTriggered(Constants.MutingVariations.For8hr)
    }

    StatusAction {
        objectName: "muteChatMenu_for24Hours"
        text: qsTr("For 24 hours")
        onTriggered: muteTriggered(Constants.MutingVariations.For24hr)
    }

    StatusAction {
        objectName: "muteChatMenu_for7Days"
        text: qsTr("For 7 days")
        onTriggered: muteTriggered(Constants.MutingVariations.For1week)
    }

    StatusAction {
        objectName: "muteChatMenu_untilTurnedOn"
        text: qsTr("Until I turn it back on")
        onTriggered: muteTriggered(Constants.MutingVariations.TillUnmuted)
    }
}
