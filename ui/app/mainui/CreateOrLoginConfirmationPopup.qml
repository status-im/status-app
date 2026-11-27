import QtQuick

import shared.popups

// Leaving a profile without a password: it goes only once another profile is in use
ConfirmationDialog {
    id: root

    signal continueRequested()

    headerSettings.title: qsTr("Create or log in to another profile?")
    confirmationText: qsTr("Your current profile and all its data will be deleted from this device once you successfully create a new profile or log in to an existing one.")
    confirmButtonObjectName: "createOrLoginContinueButton"
    confirmButtonLabel: qsTr("Continue")
    showCancelButton: true
    btnType: "normal"
    cancelBtnType: "normal"

    onConfirmButtonClicked: {
        root.continueRequested()
        root.close()
    }
    onCancelButtonClicked: root.close()
}
