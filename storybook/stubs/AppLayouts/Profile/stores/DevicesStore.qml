import QtQuick

QtObject {
    id: root

    property bool messagesBackupEnabled: false

    function setMessagesBackupEnabled(enabled) {
        root.messagesBackupEnabled = enabled
    }
}
