import QtQuick

import shared.popups
import utils

import StatusQ

ConfirmationDialog {
    id: root

    required property SecureStorage secureStorage
    required property string keyUid

    signal signOutRequested()

    confirmButtonObjectName: "signOutConfirmation"
    headerSettings.title: qsTr("Sign out")
    confirmationText: qsTr("Make sure you have your account password and recovery phrase stored. Without them you can lock yourself out of your account and lose funds.")
    confirmButtonLabel: qsTr("Sign out & Quit")

    onConfirmButtonClicked: {
        // Sign-out must clear the auto-login credential (delete-first: startup trusts
        // credential presence), and may proceed ONLY on verified deletion — otherwise
        // the next launch would silently auto-login right after an explicit sign out.
        // The per-account preference deliberately survives (the next explicit login
        // re-stores a fresh credential), and the biometric item is intentionally
        // untouched.
        const status = root.secureStorage.deleteCredential(root.keyUid)
        if (status === SecureStorage.StatusSuccess || status === SecureStorage.StatusNotFound) {
            root.signOutRequested()
            return
        }

        // Keep the session: surface the failure so the user can retry.
        Global.displayToastMessage(
                    qsTr("Failed to remove the Stay logged in credential — sign out aborted, please try again"),
                    "", "warning", false, Constants.ephemeralNotificationType.danger, "")
        root.close()
    }
}
