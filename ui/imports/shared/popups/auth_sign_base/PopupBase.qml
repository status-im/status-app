import QtQuick
import QtQuick.Controls
import QtQml.Models

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

import utils

import "states"

StatusDialog {
    id: root

    enum Purpose {
        Authentication,
        Signing
    }

    property int purpose: PopupBase.Purpose.Authentication

    required property string reason
    required property string keyUid

    required property Keychain keychain

    // interface properties
    required property string keycardState
    required property int remainingPinAttempts
    required property string userProfileKeyUid
    required property bool isKeycardKeyPair
    property var keyPairForProcessing: null

    // buttons
    required property string btnActionName
    required property string btnPasswordActionAndUpdateName
    required property string btnPinActionAndUpdateName

    // actions
    property var performPasswordAction: null // (password: string) => bool — returns true on success
    property var performKeycardAction: null // (keyUid: string, pin: string) => void — async
    property var closePopupAction: null // () => void — cancel ongoing keycard operation, destroy module


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

                if (!root.isKeycardKeyPair) {
                    return enterPasswordComponent
                }

                if (d.verifying) {
                    return keycardAuthComponent
                }

                if (!!d.error) {
                    if (keycardErrors.wrongPinError1 && root.remainingPinAttempts > 0
                            || keycardErrors.wrongPinError2) {
                        return enterPinComponent
                    }
                    if (keycardErrors.internalError
                            || keycardErrors.wrongKeycardProfileError
                            || keycardErrors.emptyKeycardError
                            || keycardErrors.notKeycardError
                            || keycardErrors.connectionKeycardError1
                            || keycardErrors.connectionKeycardError2
                            || keycardErrors.wrongPinError1
                            || keycardErrors.wrongPinError2
                            || keycardErrors.blockedPinError
                            || keycardErrors.blockedPukError
                            || keycardErrors.noAvailablePairingSlotsError) {
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
                    root.close()
                }
            }
            StatusButton {
                objectName: "keycardPopupBaseSubmitButton"
                text: d.credentialMismatchAfterBiometrics && d.usingBiometrics
                      ? root.btnPasswordActionAndUpdateName
                      : root.btnActionName
                visible: !root.isKeycardKeyPair && !d.biometricsInProgress
                enabled: !root.isKeycardKeyPair
                         && !!contentLoader.item
                         && contentLoader.item.passwordValid
                         && !d.verifying
                onClicked: {
                    if (!contentLoader.item)
                        return
                    d.performPasswordActionInternal()
                }
            }
            StatusButton {
                objectName: "keycardPopupBaseUpdatePinSubmitButton"
                text: root.btnPinActionAndUpdateName
                visible: root.isKeycardKeyPair && !d.biometricsInProgress && !d.verifying
                           && d.credentialMismatchAfterBiometrics && d.usingBiometrics
                enabled: root.isKeycardKeyPair
                         && !!contentLoader.item
                         && contentLoader.item.pinValid
                         && !d.verifying
                onClicked: {
                    if (!contentLoader.item)
                        return
                    d.performKeycardActionInternal(contentLoader.item.pin)
                }
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

            if (root.isKeycardKeyPair) {
                d.biometricsInProgress = false
                d.performKeycardActionInternal(secret)
                return
            }
            d.biometricsInProgress = false
            if (!contentLoader.item)
                return
            contentLoader.item.password = secret
            d.performPasswordActionInternal()
        }
    }

    QtObject {
        id: d

        readonly property bool usingBiometrics: root.keychain.available
                                                && root.keyUid === root.userProfileKeyUid
                                                && keychain.hasCredential(root.keyUid) === Keychain.StatusSuccess

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

            d.lastRemainingPinAttempts = root.remainingPinAttempts
            return root.remainingPinAttempts
        }

        property string lastKeycardState: Constants.keycard.state.unknownReaderState
        readonly property string processedKeycardState: {
            if (d.success || !!d.error) {
                return d.lastKeycardState
            }

            d.lastKeycardState = root.keycardState
            return root.keycardState
        }
        ////////////////////////////////////////////////////////////////////////////////

        function startBiometrics() {
            d.biometricsInProgress = true
            d.error = ""
            d.credentialCameFromBiometrics = false
            d.credentialMismatchAfterBiometrics = false
            root.keychain.requestGetCredential("authenticate", root.keyUid)
        }

        function performPasswordActionInternal() {
            if (!contentLoader.item || !root.performPasswordAction)
                return
            const password = contentLoader.item.password
            d.success = false
            d.verifying = true

            const success = root.performPasswordAction(password)

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
        }

        function performKeycardActionInternal(pin) {
            if (!root.performKeycardAction)
                return
            d.success = false
            d.verifying = true
            d.error = ""
            d.lastPin = pin
            root.performKeycardAction(root.keyUid, pin)
        }

        // Called by the concrete popup when keycard action succeeds
        function handleKeycardSuccess() {
            d.verifying = false
            d.success = true
            d.updateKeychainCredentialIfNeeded(d.lastPin)
        }

        // Called by the concrete popup when keycard action fails
        function handleKeycardError(error) {
            d.verifying = false
            d.error = error
            if (!d.usingBiometrics) {
                return
            }

            if ((keycardErrors.wrongPinError1 || keycardErrors.wrongPinError2) && d.credentialCameFromBiometrics) {
                d.credentialMismatchAfterBiometrics = true
            }
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

    ErrorsHandler {
        id: keycardErrors
        errorText: d.error
    }

    // Public API for concrete popups to drive state
    function handleKeycardSuccess() {
        d.handleKeycardSuccess()
    }

    function handleKeycardError(error) {
        d.handleKeycardError(error)
    }

    function handlePasswordSuccess() {
        d.success = true
    }

    Component.onCompleted: {
        if (d.usingBiometrics) {
            d.startBiometrics()
        }
    }

    onClosed: {
        root.keychain.cancelActiveRequest()
        if (root.closePopupAction)
            root.closePopupAction()
        destroy()
    }

    Component {
        id: biometricsComponent
        Biometrics {
            isKeycardKeyPair: root.isKeycardKeyPair
            signingPurpose: root.purpose === PopupBase.Purpose.Signing
        }
    }

    Component {
        id: enterPasswordComponent
        EnterPassword {
            onAccepted: d.performPasswordActionInternal()
        }
    }

    Component {
        id: keycardAuthComponent
        KeycardAuth {
            keycardState: d.processedKeycardState
            keycardInternalError: keycardErrors.internalError
            wrongKeycardProfile: keycardErrors.wrongKeycardProfileError
            keyPairForProcessing: root.keyPairForProcessing
        }
    }

    Component {
        id: enterPinComponent
        EnterPin {
            wrongPin: keycardErrors.wrongPinError1 || keycardErrors.wrongPinError2
            remainingAttempts: d.processedRemainingPinAttempts
            submitOnPinComplete: !d.credentialMismatchAfterBiometrics
            keyPairForProcessing: root.keyPairForProcessing
            onAccepted: d.performKeycardActionInternal(pin)
        }
    }
}
