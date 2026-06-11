import QtQuick

import StatusQ

import AppLayouts.Profile.stores as ProfileStores

import shared.popups
import utils

QtObject {
    id: root

    required property var popupParent
    required property ProfileStores.PrivacyStore privacyStore
    required property Keychain keychain

    function openPopup() {
        let enableBiometricsPopupInst = enableBiometricsPopup.createObject(popupParent)
        enableBiometricsPopupInst.open()
    }

    function showSuccessToast() {
        Global.displayToastMessage(
        qsTr("Biometric login and transaction authentication enabled for this device"),
        "", "checkmark-circle", false, Constants.ephemeralNotificationType.success, "")
    }

    readonly property Component enableBiometricsPopup: Component {
        EnableBiometricsPopup {
            id: popup

            onClosed: destroy()

            property bool enablingBiometrics: false

            onEnableBiometricsRequested: () => {
                // Enable Biometrics flow: authenticate the logged-in user, then store the returned credential to the keychain
                popup.loading = true
                popup.enablingBiometrics = true
                Global.openAuthenticationPopup(Constants.authenticationReason.enableBiometrics, root.privacyStore.keyUid, false)
            }

            Connections {
                target: Global
                enabled: popup.enablingBiometrics

                function onAuthenticationResult(reason, password, pin, keyUid) {
                    if (reason !== Constants.authenticationReason.enableBiometrics)
                        return
                    popup.enablingBiometrics = false

                    const credential = pin !== "" ? pin : password
                    // If credential not retrieved (cancelled or failed)
                    if (keyUid === "" || credential === "") {
                        popup.loading = false
                        popup.errorText = qsTr("Biometric setup failed. Try again.")
                        return
                    }

                    const status = keychain.saveCredential(keyUid, credential)

                    if (status !== Keychain.StatusSuccess) {
                        popup.loading = false
                        popup.errorText = qsTr("Biometric setup failed. Try again.")
                    }
                }
            }
            Connections {
                target: keychain

                function onCredentialSaved(account: string) {
                    popup.loading = false
                    popup.close()
                    root.showSuccessToast()
                }

                function onGetCredentialRequestCompleted(status, secret) {
                    if (status !== Keychain.StatusSuccess) {
                        popup.loading = false
                        popup.errorText = qsTr("Biometric setup failed. Try again.")
                    }
                }
            }
        }
    }
}
