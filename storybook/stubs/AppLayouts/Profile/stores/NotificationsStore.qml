import QtQml

QtObject {
    id: root

    property var notificationsModule: null

    readonly property QtObject notificationsSettings: QtObject {
        property bool remotePushNotificationsEnabled: false
        property bool notifSettingAllowNotifications: false
    }

    readonly property ListModel exemptionsModel: ListModel {}

    function loadExemptions() {}
    function sendTestNotification(title, message) {}
    function saveExemptions(itemId, muteAllMessages, personalMentions, globalMentions, allMessages) {}
}
