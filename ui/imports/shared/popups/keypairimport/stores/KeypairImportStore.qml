import QtQuick
import utils

import StatusQ.Core.Backpressure

import "../../common"

BasePopupStore {
    id: root

    isAddAccountPopup: false
    required property var keypairImportModule

    property bool userProfileMigratedToColdWallet: userProfile.migratedToColdWallet
    property bool userProfileUsingBiometricLogin: userProfile.usingBiometricLogin
    property bool syncViaQr: true

    // Module Properties
    property var currentState: root.keypairImportModule.currentState
    property var selectedKeypair: root.keypairImportModule.selectedKeypair
    enteredPrivateKeyMatchTheKeypair: root.keypairImportModule.enteredPrivateKeyMatchTheKeypair
    privateKeyAccAddress: root.keypairImportModule.privateKeyAccAddress

    submitPopup: function(event) {
        if (!root.syncViaQr && !root.primaryPopupButtonEnabled) {
            return
        }

        if(!event) {
            root.currentState.doPrimaryAction()
        }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true
            root.currentState.doPrimaryAction()
        }
    }

    readonly property Connections _authRequestConnections: Connections {
        target: root.keypairImportModule
        function onAuthenticationRequested(keyUid: string) {
            Global.openAuthenticationPopup(Constants.authenticationReason.importKeypair, keyUid, false)
        }
    }
    readonly property Connections _authResultConnections: Connections {
        target: Global
        function onAuthenticationResult(reason: string, password: string, pin: string, keyUid: string) {
            if (reason !== Constants.authenticationReason.importKeypair)
                return
            root.keypairImportModule.authenticationCompleted(password, pin, keyUid)
        }
    }

    changePrivateKeyPostponed: Backpressure.debounce(root, 400, function (privateKey) {
        root.keypairImportModule.changePrivateKey(privateKey)
    })

    cleanPrivateKey: function() {
        root.enteredPrivateKeyIsValid = false
        root.keypairImportModule.changePrivateKey("")
    }

    function validSeedPhrase(seedPhrase) {
        return root.keypairImportModule.validSeedPhrase(seedPhrase)
    }

    function changeSeedPhrase(seedPhrase) {
        root.keypairImportModule.changeSeedPhrase(seedPhrase)
    }

    readonly property bool primaryPopupButtonEnabled: {
        if (root.currentState.stateType === Constants.keypairImportPopup.state.importQr) {
            return !root.syncViaQr &&
                    !!root.keypairImportModule.connectionString &&
                    !root.keypairImportModule.connectionStringError
        }

        if (root.currentState.stateType === Constants.keypairImportPopup.state.importPrivateKey) {
            return root.enteredPrivateKeyIsValid &&
                    root.enteredPrivateKeyMatchTheKeypair &&
                    !!root.privateKeyAccAddress &&
                    root.privateKeyAccAddress.detailsLoaded &&
                    root.privateKeyAccAddress.alreadyCreatedChecked &&
                    root.privateKeyAccAddress.alreadyCreated &&
                    root.privateKeyAccAddress.address !== ""
        }

        if (root.currentState.stateType === Constants.keypairImportPopup.state.importSeedPhrase) {
            return root.enteredSeedPhraseIsValid
        }

        return true
    }

    function generateConnectionStringForExporting() {
        root.keypairImportModule.generateConnectionStringForExporting()
    }

    function validateConnectionString(connectionString) {
        return root.keypairImportModule.validateConnectionString(connectionString)
    }
}
