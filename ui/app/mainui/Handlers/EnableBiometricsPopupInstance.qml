import QtQuick

import StatusQ

import AppLayouts.Profile.stores as ProfileStores

import shared.popups
import utils

EnableBiometricsPopup {
    id: popup

    required property ProfileStores.PrivacyStore privacyStore
    required property Keychain keychain

    onClosed: destroy()

    property bool enablingBiometrics: false

    onEnableBiometricsRequested: () => {
        // Enable Biometrics flow: authenticate the logged-in user, then store the returned credential to the keychain
        popup.loading = true
        popup.enablingBiometrics = true
        Global.openAuthenticationPopup(Constants.authenticationReason.enableBiometrics, popup.privacyStore.keyUid, false)
    }

    Connections {
        target: Global
        enabled: popup.enablingBiometrics

        function onAuthenticationResult(reason, password, pin, keyUid) {
            if (reason !== Constants.authenticationReason.enableBiometrics)
                return
            popup.enablingBiometrics = false

            const credential = pin !== "" ?
                                 pin
                               : popup.privacyStore.getBiometricCredentialForStorage(keyUid, password)
            // If credential not retrieved (cancelled, failed, or could not be prepared)
            if (keyUid === "" || credential === "") {
                popup.loading = false
                popup.errorText = qsTr("Biometric setup failed. Try again.")
                return
            }

            const status = popup.keychain.saveCredential(keyUid, credential)

            if (status !== Keychain.StatusSuccess) {
                popup.loading = false
                popup.errorText = qsTr("Biometric setup failed. Try again.")
            }
        }
    }
    Connections {
        target: popup.keychain

        function onCredentialSaved(account: string) {
            popup.loading = false
            popup.close()
            Global.displayToastMessage(
                qsTr("Biometric login and transaction authentication enabled for this device"),
                "", "checkmark-circle", false, Constants.ephemeralNotificationType.success, "")
        }

        function onGetCredentialRequestCompleted(status, secret) {
            if (status !== Keychain.StatusSuccess) {
                popup.loading = false
                popup.errorText = qsTr("Biometric setup failed. Try again.")
            }
        }
    }
}
