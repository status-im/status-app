import QtQuick

import StatusQ

import AppLayouts.Profile.stores as ProfileStores

import shared.popups
import utils

// Sets the first password of a zero-onboarded profile, then continues the action that asked for it
QtObject {
    id: root

    required property var popupParent
    required property var passwordStrengthScoreFunction
    required property ProfileStores.PrivacyStore privacyStore
    required property SecureStorage secureStorage
    required property Keychain keychain

    // onSuccess(password) runs after the popup has closed; onCancel when it closes without a password.
    // A request arriving while the popup is open waits for the same password.
    function requirePassword(title: string, onSuccess, onCancel) : void {
        if (d.popup) {
            d.popup.requests.push({ onSuccess, onCancel })
            return
        }
        d.popup = popupComponent.createObject(root.popupParent, {
            requests: [{ onSuccess, onCancel }], title: title || qsTr("Create profile password")
        })
        d.popup.open()
    }

    readonly property QtObject _d: QtObject {
        id: d

        property CreatePasswordPopup popup

        // Same outcome as the onboarding page: the credential saved at creation stays only if asked for
        function applyToggles(password: string, stayLoggedInOffered: bool, stayLoggedIn: bool, enableBiometrics: bool) : void {
            // The save right after creation may have failed
            if (stayLoggedInOffered && stayLoggedIn
                    && root.secureStorage.hasCredential(root.privacyStore.keyUid) === SecureStorage.StatusNotFound) {
                const credential = root.privacyStore.getStayLoggedInCredentialForStorage(root.privacyStore.keyUid, password)
                if (credential !== "" && root.secureStorage.setCredential(root.privacyStore.keyUid, credential) === SecureStorage.StatusSuccess)
                    root.privacyStore.setStayLoggedIn(true)
                else
                    Global.displayToastMessage(qsTr("Failed to save the password for automatic login"),
                                               "", "warning", false, Constants.ephemeralNotificationType.danger, "")
            }
            if (stayLoggedInOffered && !stayLoggedIn) {
                const status = root.secureStorage.deleteCredential(root.privacyStore.keyUid)
                if (status === SecureStorage.StatusSuccess || status === SecureStorage.StatusNotFound)
                    root.privacyStore.setStayLoggedIn(false)
                else
                    Global.displayToastMessage(qsTr("Failed to remove the saved password"),
                                               "", "warning", false, Constants.ephemeralNotificationType.danger, "")
            }
            if (enableBiometrics) {
                const credential = root.privacyStore.getBiometricCredentialForStorage(root.privacyStore.keyUid, password)
                if (credential === "" || root.keychain.saveCredential(root.privacyStore.keyUid, credential) !== Keychain.StatusSuccess)
                    Global.displayToastMessage(qsTr("Failed to enable biometric login and transaction authentication for this device"),
                                               "", "warning", false, Constants.ephemeralNotificationType.danger, "")
            }
        }
    }

    readonly property Component popupComponent: Component {
        CreatePasswordPopup {
            id: popup

            property var requests: []
            property string password
            property bool stayLoggedInOffered
            property bool stayLoggedIn
            property bool enableBiometrics
            property bool passwordSet: false

            objectName: "createPasswordPopup"
            destroyOnClose: true
            passwordStrengthScoreFunction: root.passwordStrengthScoreFunction
            stayLoggedInAvailable: root.secureStorage.available
            biometricsAvailable: root.keychain.available

            onSubmitted: (password, stayLoggedIn, enableBiometrics) => {
                popup.password = password
                popup.stayLoggedInOffered = popup.stayLoggedInAvailable
                popup.stayLoggedIn = stayLoggedIn
                popup.enableBiometrics = enableBiometrics
                popup.errorText = ""
                popup.loading = true
                root.privacyStore.setProfilePassword(password)
            }

            onClosed: {
                d.popup = null
                const requests = popup.requests
                if (!popup.passwordSet) {
                    requests.forEach(request => request.onCancel?.())
                    return
                }
                const password = popup.password
                Qt.callLater(() => requests.forEach(request => request.onSuccess?.(password)))
            }

            readonly property Connections resultConnections: Connections {
                target: root.privacyStore
                enabled: popup.loading

                function onProfilePasswordSet(success: bool, errorMsg: string) {
                    popup.loading = false
                    if (!success) {
                        popup.errorText = qsTr("The password could not be set. Please try again.")
                        return
                    }
                    popup.passwordSet = true
                    d.applyToggles(popup.password, popup.stayLoggedInOffered, popup.stayLoggedIn, popup.enableBiometrics)
                    popup.close()
                }
            }
        }
    }
}
