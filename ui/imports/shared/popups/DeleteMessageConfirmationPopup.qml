import QtQuick

import AppLayouts.Chat.stores

ConfirmationDialog {
    id: root

    property MessageStore messageStore
    property string messageId

    headerSettings.title: qsTr("Confirm deleting this message")
    confirmationText: qsTr("Are you sure you want to delete this message? Be aware that other clients are not guaranteed to delete the message as well.")
    doNotShowAgainOptionVisible: true
    confirmButtonObjectName: "chatButtonsPanelConfirmDeleteMessageButton"

    executeConfirm: () => {
        if (doNotShowAgainChecked) {
            localAccountSensitiveSettings.showDeleteMessageWarning = false
        }
        close()
        messageStore.deleteMessage(messageId)
    }

    onClosed: {
        destroy()
    }
}
