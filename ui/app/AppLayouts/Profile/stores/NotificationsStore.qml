import QtQml

QtObject {
    id: root

    property var notificationsModule
    readonly property var notificationsSettings: appSettings

    readonly property var exemptionsModel: notificationsModule.exemptionsModel

    function loadExemptions() {
        root.notificationsModule.loadExemptions()
    }

    function sendTestNotification(title, message) {
        root.notificationsModule.sendTestNotification(title, message)
    }

    function saveExemptions(itemId, muteAllMessages, personalMentions, globalMentions, allMessages) {
        root.notificationsModule.saveExemptions(itemId, muteAllMessages, personalMentions, globalMentions, allMessages)
    }
}
