import QtQuick
import QtQuick.Controls
import QtQml.Models

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

import utils

import "states"
import "stores"

StatusDialog {
    id: root

    required property string reason
    required property string keyUid

    required property AuthenticationStore store
    required property Keychain keychain

    signal authenticationSuccess(string reason, string password, string pin, string keyUid)
    signal authenticationCancelled()

    title: qsTr("Authenticate")

    width: Constants.keycard.general.popupWidth
    padding: Theme.halfPadding

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    contentItem: Item {
        implicitHeight: Constants.keycard.general.popupHeight

        Loader {
            id: contentLoader
            anchors.fill: parent

            sourceComponent: {
                if (d.biometricsInProgress) {
                    return biometricsComponent
                }

                if (!d.isKeycardKeyPair) {
                    return enterPasswordComponent
                }

                if (d.verifying) {
                    return keycardAuthComponent
                }

                if (!!d.error) {
                    if (d.wrongPinError1 && root.store.remainingPinAttempts > 0
                            || d.wrongPinError2) {
                        return enterPinComponent
                    }
                    if (d.wrongKeycardError
                            || d.emptyKeycardError
                            || d.notKeycardError
                            || d.connectionKeycardError1
                            || d.connectionKeycardError2
                            || d.wrongPinError1
                            || d.wrongPinError2
                            || d.blockedPinError
                            || d.blockedPukError
                            || d.noAvailablePairingSlotsError) {
                        return keycardAuthComponent
                    }
                }

                if (d.success) {
                    return keycardAuthComponent
                }

                return enterPinComponent
            }
        }
    }

    footer: StatusDialogFooter {
        rightButtons: ObjectModel {
            StatusFlatButton {
                visible: d.usingBiometrics && !d.biometricsInProgress && !d.verifying
                text: qsTr("Use biometrics")
                onClicked: d.startBiometrics()
            }
            StatusFlatButton {
                text: qsTr("Cancel")
                onClicked: {
                    root.authenticationCancelled()
                    root.close()
                }
            }
            StatusButton {
                objectName: "authenticationPopupSubmitButton"
                text: d.credentialMismatchAfterBiometrics && d.usingBiometrics
                      ? qsTr("Update password & authenticate")
                      : qsTr("Authenticate")
                visible: !d.isKeycardKeyPair && !d.biometricsInProgress
                enabled: !d.isKeycardKeyPair
                         && !!contentLoader.item
                         && contentLoader.item.passwordValid
                         && !d.verifying
                onClicked: {
                    if (!contentLoader.item)
                        return
                    d.authenticatePassword()
                }
            }
            StatusButton {
                objectName: "authenticationPopupUpdatePinSubmitButton"
                text: qsTr("Update PIN & authenticate")
                visible: d.isKeycardKeyPair && !d.biometricsInProgress && !d.verifying
                           && d.credentialMismatchAfterBiometrics && d.usingBiometrics
                enabled: d.isKeycardKeyPair
                         && !!contentLoader.item
                         && contentLoader.item.pinValid
                         && !d.verifying
                onClicked: {
                    if (!contentLoader.item)
                        return
                    d.authenticateKeycard(contentLoader.item.pin)
                }
            }
        }
    }

    Connections {
        target: root.store

        function onKeycardAuthSuccess(encryptionPublicKey) {
            d.verifying = false
            d.success = true
            d.updateKeychainCredentialIfNeeded(d.lastPin)
            root.authenticationSuccess(root.reason, encryptionPublicKey, d.lastPin, root.keyUid)
            root.close()
        }

        function onKeycardAuthError(error) {
            d.verifying = false
            d.error = error
            if (!d.usingBiometrics) {
                return
            }

            if ((d.wrongPinError1 || d.wrongPinError2) && d.credentialCameFromBiometrics) {
                d.credentialMismatchAfterBiometrics = true
            }
        }
    }

    Connections {
        target: root.keychain

        function onGetCredentialRequestCompleted(status, secret) {
            if (!d.biometricsInProgress || !root.opened) {
                return
            }
            if (status !== Keychain.StatusSuccess || secret.length === 0) {
                d.biometricsInProgress = false
                d.showToast(status)
                return
            }
            d.showToast(status)
            d.credentialCameFromBiometrics = true

            if (d.isKeycardKeyPair) {
                d.biometricsInProgress = false
                d.authenticateKeycard(secret)
                return
            }
            d.biometricsInProgress = false
            if (!contentLoader.item)
                return
            contentLoader.item.password = secret
            d.authenticatePassword()
        }
    }

    QtObject {
        id: d

        readonly property bool usingBiometrics: root.keychain.available
                                                && root.keyUid === root.store.userProfileKeyUid
                                                && keychain.hasCredential(root.keyUid) === Keychain.StatusSuccess

        readonly property QtObject errKeyword: QtObject {
            readonly property string wrongKeycard: "profile does not match" // "Keycard profile does not match the profile (keyUid) being tried to export public key for"
            readonly property string wrongPin1: "Wrong PIN" // "Wrong PIN. Remaining attempts: X"
            readonly property string wrongPin2: "PIN must be 6 digits" // "PIN must be 6 digits"
            readonly property string connection1: "Failed to connect to card" // "Failed to connect to card in reader: ..."
            readonly property string connection2: Constants.keycard.state.connectionError // Card not ready (state: connection-error)"
            readonly property string emptyKeycard: Constants.keycard.state.emptyKeycard // "Card not ready (state: empty-keycard)"
            readonly property string notKeycard: Constants.keycard.state.notKeycard // "Card not ready (state: not-keycard)"
            readonly property string blockedPin: Constants.keycard.state.blockedPIN // "Card not ready (state: blocked-pin)
            readonly property string blockedPuk: Constants.keycard.state.blockedPUK // "Card not ready (state: blocked-puk)"
            readonly property string noAvailablePairingSlots: Constants.keycard.state.noAvailablePairingSlots // "Card not ready (state: no-available-pairing-slots)"
        }

        readonly property bool wrongKeycardError: d.error.toLowerCase().indexOf(errKeyword.wrongKeycard.toLowerCase()) > -1
        readonly property bool wrongPinError1: d.error.toLowerCase().indexOf(errKeyword.wrongPin1.toLowerCase()) > -1
        readonly property bool wrongPinError2: d.error.toLowerCase().indexOf(errKeyword.wrongPin2.toLowerCase()) > -1
        readonly property bool connectionKeycardError1: d.error.toLowerCase().indexOf(errKeyword.connection1.toLowerCase()) > -1
        readonly property bool connectionKeycardError2: d.error.toLowerCase().indexOf(errKeyword.connection2.toLowerCase()) > -1
        readonly property bool emptyKeycardError: d.error.toLowerCase().indexOf(errKeyword.emptyKeycard.toLowerCase()) > -1
        readonly property bool notKeycardError: d.error.toLowerCase().indexOf(errKeyword.notKeycard.toLowerCase()) > -1
        readonly property bool blockedPinError: d.error.toLowerCase().indexOf(errKeyword.blockedPin.toLowerCase()) > -1
        readonly property bool blockedPukError: d.error.toLowerCase().indexOf(errKeyword.blockedPuk.toLowerCase()) > -1
        readonly property bool noAvailablePairingSlotsError: d.error.toLowerCase().indexOf(errKeyword.noAvailablePairingSlots.toLowerCase()) > -1

        property bool isKeycardKeyPair: false
        property bool biometricsInProgress: false
        property bool credentialMismatchAfterBiometrics: false
        property bool credentialCameFromBiometrics: false
        property bool verifying: false
        property bool success: false
        property string error: ""
        property string lastPin: ""

        function updateKeychainCredentialIfNeeded(credential) {
            if (!d.credentialMismatchAfterBiometrics) {
                return
            }

            const status = root.keychain.updateCredential(root.keyUid, credential)
            if (status !== Keychain.StatusSuccess) {
                Global.displayToastMessage(qsTr("Failed to update stored credentials"), "", "warning", false, Constants.ephemeralNotificationType.danger, "")
            }
        }


        ////////////////////////////////////////////////////////////////////////////////
        // Keycard state snapshot at the moment the response is received
        ////////////////////////////////////////////////////////////////////////////////
        property int lastRemainingPinAttempts: -1
        readonly property int processedRemainingPinAttempts: {
            if (d.success || !!d.error) {
                return d.lastRemainingPinAttempts
            }

            d.lastRemainingPinAttempts = root.store.remainingPinAttempts
            return root.store.remainingPinAttempts
        }

        property string lastKeycardState: Constants.keycard.state.unknownReaderState
        readonly property string processedKeycardState: {
            if (d.success || !!d.error) {
                return d.lastKeycardState
            }

            d.lastKeycardState = root.store.keycardState
            return root.store.keycardState
        }
        ////////////////////////////////////////////////////////////////////////////////

        function startBiometrics() {
            d.biometricsInProgress = true
            d.error = ""
            d.credentialCameFromBiometrics = false
            d.credentialMismatchAfterBiometrics = false
            root.keychain.requestGetCredential("authenticate", root.keyUid)
        }

        function authenticatePassword() {
            if (!contentLoader.item)
                return
            const password = contentLoader.item.password
            d.success = false
            d.verifying = true

            const success = root.store.verifyPassword(password)

            d.verifying = false

            if (!success) {
                if (contentLoader.item.wrongPassword !== undefined) {
                    contentLoader.item.wrongPassword = true
                }
                if (d.usingBiometrics && d.credentialCameFromBiometrics) {
                    d.credentialMismatchAfterBiometrics = true
                }
                return
            }

            d.updateKeychainCredentialIfNeeded(password)
            d.success = true
            root.authenticationSuccess(root.reason, password, "", root.keyUid)
            root.close()
        }

        function authenticateKeycard(pin) {
            d.success = false
            d.verifying = true
            d.error = ""
            d.lastPin = pin
            root.store.startKeycardAuthentication(root.keyUid, pin)
        }

        function showToast(status) {
            if (status === Keychain.StatusSuccess) {
                Global.displayToastMessage(
                            qsTr("Credentials successfully obtained from biometrics"),
                            "", "checkmark-circle", false, Constants.ephemeralNotificationType.success, "")
                return
            }
            let text = ""
            switch(status) {
            case Keychain.StatusNotSupported: {
                text = qsTr("Biometrics not supported")
                break
            }
            case Keychain.StatusGenericError: {
                text = qsTr("Generic error occurred")
                break
            }
            case Keychain.StatusUnavailable: {
                text = qsTr("Biometrics is unavailable")
                break
            }
            case Keychain.StatusCancelled: {
                text = qsTr("Biometrics cancelled")
                break
            }
            case Keychain.StatusNotFound: {
                text = qsTr("Biometrics not found")
                break
            }
            case Keychain.StatusFallbackSelected: {
                text = qsTr("Biometrics fallback error")
                break
            }
            default:
                text = qsTr("Unknown biometrics error")
            }

            Global.displayToastMessage(text, "", "warning", false, Constants.ephemeralNotificationType.danger, "")
        }
    }

    Component.onCompleted: {
        root.store.prepare()
        d.isKeycardKeyPair = root.store.isKeypairMigratedToKeycard(root.keyUid)
        if (d.usingBiometrics) {
            d.startBiometrics()
        }
    }

    onClosed: {
        root.keychain.cancelActiveRequest()
        root.store.stopKeycardAuthentication()
        destroy()
    }

    Component {
        id: biometricsComponent
        Biometrics {}
    }

    Component {
        id: enterPasswordComponent
        EnterPassword {
            onAccepted: d.authenticatePassword()
        }
    }

    Component {
        id: keycardAuthComponent
        KeycardAuth {
            keycardState: d.processedKeycardState
            wrongKeycard: d.wrongKeycardError
        }
    }

    Component {
        id: enterPinComponent
        EnterPin {
            wrongPin: d.wrongPinError1 || d.wrongPinError2
            remainingAttempts: d.processedRemainingPinAttempts
            submitOnPinComplete: !d.credentialMismatchAfterBiometrics
            onAccepted: d.authenticateKeycard(pin)
        }
    }
}
