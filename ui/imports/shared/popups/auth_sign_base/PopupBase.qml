import QtQuick
import QtQuick.Controls
import QtQml.Models

import StatusQ
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Popups.Dialog

import utils

import shared.popups.keycard_new.helpers 1.0

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
    required property string keycardUid
    required property int remainingPinAttempts
    required property string userProfileKeyUid
    required property string userProfilePublicKey
    required property bool userProfileMigratedToColdWallet
    required property bool isKeycardKeyPair
    property var keyPairForProcessing: null

    // a logic about key pair being used for authentication/signing as well as the location of signing (keycard/keystore file) is determined by these readonly props here
    readonly property bool useKeycard: root.isKeycardKeyPair
                                       || root.userProfileMigratedToColdWallet
    readonly property string useKeyUid: root.isKeycardKeyPair?
                                            root.keyUid
                                          : root.userProfileKeyUid

    property bool externalAuthorization: false // when set, the credential is not collected here, instead an "Authorize" buutton is shown, emitting authorizeRequested signal

    property var getCredentialForStorage: null // (keyUid: string, password: string) => string - value to store in the OS keychain, if "" signals failure

    // Set for flows that need the actual password and cannot accept the profile's DEK
    // (e.g. device syncing, where the password itself is validated against and transferred
    // with the keystore). When the biometric secret turns out to be a DEK, the popup falls
    // back to manual password entry instead.
    property bool requirePlainCredential: false

    signal authorizeRequested()

    // buttons
    required property string btnActionName
    required property string btnPasswordActionAndUpdateName
    required property string btnPinActionAndUpdateName

    // actions
    property var performPasswordAction: null // (password: string) => bool — returns true on success
    property var performKeycardAction: null // (keyUid: string, pin: string, pairingPassword: string) => void — async
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

                if (!root.useKeycard) {
                    return enterPasswordComponent
                }

                if (root.externalAuthorization) {
                    return enterPinComponent
                }

                if (d.verifying) {
                    return keycardAuthComponent
                }

                if (d.pairingPasswordRequired) {
                    return enterPairingPasswordComponent
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
                objectName: "useBiometricsButton"
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
                visible: !root.useKeycard && !d.biometricsInProgress
                enabled: !root.useKeycard
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
                objectName: "keycardPairingPasswordSubmitButton"
                text: qsTr("Continue")
                visible: contentLoader.status === Loader.Ready
                         && contentLoader.sourceComponent === enterPairingPasswordComponent
                enabled: !!contentLoader.item && contentLoader.item.pairingPasswordValid && !d.verifying
                onClicked: {
                    if (!contentLoader.item)
                        return
                    contentLoader.item.accepted()
                }
            }
            StatusButton {
                objectName: "keycardPopupBaseUpdatePinSubmitButton"
                text: root.btnPinActionAndUpdateName
                visible: root.useKeycard && !d.biometricsInProgress && !d.verifying
                           && d.credentialMismatchAfterBiometrics && d.usingBiometrics
                enabled: root.useKeycard
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

            if (root.useKeycard) {
                d.biometricsInProgress = false
                d.performKeycardActionInternal(secret)
                return
            }
            d.biometricsInProgress = false
            if (!contentLoader.item)
                return

            let value = secret
            d.lastSecretWasLegacy = true
            if (value.startsWith(Constants.keychain.dekPrefix)) {
                value = value.slice(Constants.keychain.dekPrefix.length)
                d.lastSecretWasLegacy = false
                if (root.requirePlainCredential) {
                    d.credentialCameFromBiometrics = false
                    Global.displayToastMessage(
                                qsTr("Please enter your password — biometrics cannot be used for this action"),
                                "",
                                "warning",
                                false,
                                Constants.ephemeralNotificationType.danger,
                                "")
                    return
                }
            }
            contentLoader.item.password = value
            d.performPasswordActionInternal()
        }
    }

    QtObject {
        id: d

        readonly property bool usingBiometrics: root.keychain.available
                                                && !root.externalAuthorization // the authentication popup runs its own biometrics
                                                && (!root.isKeycardKeyPair || root.keyUid === root.userProfileKeyUid)
                                                && keychain.hasCredential(root.useKeyUid) === Keychain.StatusSuccess

        onUsingBiometricsChanged: d.tryAutoStartBiometrics()

        property bool constructionDone: false
        property bool autoBiometricsAttempted: false

        function tryAutoStartBiometrics() {
            if (!d.constructionDone || !d.usingBiometrics || d.autoBiometricsAttempted)
                return
            d.autoBiometricsAttempted = true
            if (d.biometricsInProgress || d.verifying || d.success)
                return
            d.startBiometrics()
        }

        property bool biometricsInProgress: false
        property bool credentialMismatchAfterBiometrics: false
        property bool credentialCameFromBiometrics: false
        property bool lastSecretWasLegacy: false
        property bool verifying: false
        property bool success: false
        property string error: ""
        property string lastPin: ""

        function updateKeychainCredentialIfNeeded(credential, isPin) {
            // If successful action:
            // - biometrics produced a stale credential, the user typed a working one
            // - biometrics produced a legacy (untagged) credential - refresh it so DEK-migrated profiles store the wrapped DEK instead of the raw password
            const upgrade = d.credentialCameFromBiometrics && d.lastSecretWasLegacy && !isPin
            if (!d.credentialMismatchAfterBiometrics && !upgrade) {
                return
            }

            let toStore = credential
            if (!isPin) {
                if (!root.getCredentialForStorage)
                    return
                toStore = root.getCredentialForStorage(root.useKeyUid, credential)
            }

            if (toStore === ""
                    || root.keychain.updateCredential(root.useKeyUid, toStore) !== Keychain.StatusSuccess) {
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
            d.lastSecretWasLegacy = false
            root.keychain.requestGetCredential("authenticate", root.useKeyUid)
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

            d.updateKeychainCredentialIfNeeded(password, false)
            d.success = true
        }

        property string pairingPassword: ""
        property string pairingPasswordKeycardUid: ""
        property bool keycardActionAttempted: false
        readonly property bool pairingPasswordRequired: !d.verifying
                                                        && d.keycardActionAttempted
                                                        && (keycardErrors.pairingPasswordRequiredError
                                                            || root.keycardState === Constants.keycard.state.pairingError)
        readonly property bool wrongPairingPassword: d.pairingPasswordRequired && d.pairingPassword !== ""

        function performKeycardActionInternal(pin) {
            if (!root.performKeycardAction)
                return
            d.success = false
            d.verifying = true
            d.error = ""
            d.lastPin = pin
            d.keycardActionAttempted = true
            root.performKeycardAction(root.useKeyUid, pin, d.pairingPassword)
        }

        // Called by the concrete popup when keycard action succeeds
        function handleKeycardSuccess() {
            d.verifying = false
            d.success = true
            d.updateKeychainCredentialIfNeeded(d.lastPin, true)
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

    readonly property string lastUsedPin: d.lastPin

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
        d.constructionDone = true
        d.tryAutoStartBiometrics()
    }

    onClosed: {
        // Cancel the keychain request started from this popup, because the keychain is shared, and on success another flow
        // (e.g. enabling biometrics) may have already started its own request by the time this popup closes.
        if (d.biometricsInProgress)
            root.keychain.cancelActiveRequest()
        if (root.closePopupAction)
            root.closePopupAction()
        destroy()
    }

    Component {
        id: biometricsComponent
        Biometrics {
            isKeycardKeyPair: root.useKeycard
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
        id: enterPairingPasswordComponent
        EnterPairingPassword {
            wrongPairingPassword: d.wrongPairingPassword

            Component.onCompleted: {
                d.pairingPasswordKeycardUid = root.keycardUid
            }

            onAccepted: {
                if (root.keycardUid !== d.pairingPasswordKeycardUid) {
                    d.pairingPassword = ""
                    return
                }
                d.pairingPassword = pairingPassword
                d.performKeycardActionInternal(d.lastPin)
            }
        }
    }

    Component {
        id: keycardAuthComponent
        KeycardAuth {
            userProfilePublicKey: root.userProfilePublicKey
            keycardState: d.processedKeycardState
            keycardInternalError: keycardErrors.internalError
            wrongKeycardProfile: keycardErrors.wrongKeycardProfileError
            keyPairForProcessing: root.keyPairForProcessing
        }
    }

    Component {
        id: enterPinComponent
        EnterPin {
            userProfilePublicKey: root.userProfilePublicKey
            wrongPin: keycardErrors.wrongPinError1 || keycardErrors.wrongPinError2
            remainingAttempts: d.processedRemainingPinAttempts
            submitOnPinComplete: !d.credentialMismatchAfterBiometrics
            keyPairForProcessing: root.keyPairForProcessing
            authorizeMode: root.externalAuthorization
            onAccepted: d.performKeycardActionInternal(pin)
            onAuthorizeRequested: root.authorizeRequested()
        }
    }
}
