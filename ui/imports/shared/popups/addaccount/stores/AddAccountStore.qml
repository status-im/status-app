import QtQuick
import utils

import StatusQ.Core.Backpressure

import "../../common"

BasePopupStore {
    id: root

    isAddAccountPopup: true
    required property var addAccountModule
    required property var emojiPopup

    property string userProfilePublicKey: userProfile.pubKey
    property string userProfileKeyUid: userProfile.keyUid
    property bool userProfileMigratedToColdWallet: userProfile.migratedToColdWallet
    property bool userProfileUsingBiometricLogin: userProfile.usingBiometricLogin

    // Module Properties
    property var currentState: root.addAccountModule.currentState
    property var originModel: root.addAccountModule.originModel
    property var selectedOrigin: root.addAccountModule.selectedOrigin
    property var derivedAddressModel: root.addAccountModule.derivedAddressModel
    property var selectedDerivedAddress: root.addAccountModule.selectedDerivedAddress
    property var watchOnlyAccAddress: root.addAccountModule.watchOnlyAccAddress
    privateKeyAccAddress: root.addAccountModule.privateKeyAccAddress
    property bool editMode: root.addAccountModule.editMode
    property bool disablePopup: root.addAccountModule.disablePopup

    property bool accountNameIsValid: false
    property bool addingNewMasterKeyConfirmed: false
    property bool seedPhraseRevealed: false
    property bool seedPhraseWord1Valid: false
    property int seedPhraseWord1WordNumber: -1
    property bool seedPhraseWord2Valid: false
    property int seedPhraseWord2WordNumber: -1
    property bool seedPhraseBackupConfirmed: false
    property bool derivationPathOutOfTheDefaultStatusDerivationTreeConfirmed: false
    property bool derivationPathOutOfTheDefaultStatusDerivationTree: root.addAccountModule?
                                                                         !root.addAccountModule.derivationPath.startsWith(Constants.addAccountPopup.predefinedPaths.ethereum) ||
                                                                         (root.addAccountModule.derivationPath.match(/'/g) || []).length !== 3 ||
                                                                         (root.addAccountModule.derivationPath.match(/\//g) || []).length !== 5
                                                                       : false

    property bool derivationPathEditingNotValid: false

    readonly property var derivationPathRegEx: /^(m\/44'\/)([0-9|'|\/](?!\/'))*$/
    property string selectedRootPath: Constants.addAccountPopup.predefinedPaths.ethereum
    readonly property var roots: {
        // Cold wallet key pairs derive from the stored xpub, so no Custom and Ethereum Ledger Live options
        // TODO: once regular key pairs switch to derive from xpub, Custom and Ethereum Ledger Live options
        // will be completely removed.
        if (!!root.selectedOrigin && root.selectedOrigin.migratedToColdWallet) {
            return [Constants.addAccountPopup.predefinedPaths.ethereum,
                    Constants.addAccountPopup.predefinedPaths.ethereumLedger]
        }
        return [Constants.addAccountPopup.predefinedPaths.custom,
                Constants.addAccountPopup.predefinedPaths.ethereum,
                Constants.addAccountPopup.predefinedPaths.ethereumLedger,
                Constants.addAccountPopup.predefinedPaths.ethereumLedgerLive]
    }

    readonly property bool isWatchOnlyImport: root.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.unknown &&
                                            root.selectedOrigin.keyUid === Constants.appTranslatableConstants.addAccountLabelOptionAddWatchOnlyAcc

    signal showLimitPopup(int warningType)
    signal resolvedENS(string resolvedPubKey, string resolvedAddress, string uuid)

    Component.onCompleted: {
        mainModule.resolvedENS.connect(root.resolvedENS)
    }

    function resetStoreValues() {
        root.enteredSeedPhraseIsValid = false
        root.enteredPrivateKeyIsValid = false
        root.addingNewMasterKeyConfirmed = false
        root.seedPhraseRevealed = false
        root.seedPhraseWord1Valid = false
        root.seedPhraseWord1WordNumber = -1
        root.seedPhraseWord2Valid = false
        root.seedPhraseWord2WordNumber = -1
        root.seedPhraseBackupConfirmed = false
        root.derivationPathOutOfTheDefaultStatusDerivationTreeConfirmed = false
        root.selectedRootPath = Constants.addAccountPopup.predefinedPaths.ethereum

        if (!root.editMode) {
            root.cleanPrivateKey()
            root.cleanSeedPhrase()
        }
    }

    function getStoredAccountName() {
        return root.addAccountModule.getStoredAccountName()
    }

    function getStoredSelectedEmoji() {
        return root.addAccountModule.getStoredSelectedEmoji()
    }

    function getStoredSelectedColorId() {
        return root.addAccountModule.getStoredSelectedColorId()
    }

    submitPopup: function(event) {
        if (!root.primaryPopupButtonEnabled) {
            return
        }

        const handleEvent = !event || event.key === Qt.Key_Return || event.key === Qt.Key_Enter
        if (!handleEvent) {
            return
        }

        if (handleEvent && !!event) {
            event.accepted = true
        }

        if (root.editMode) {
            root.currentState.doPrimaryAction()
            return
        }

        if (root.isWatchOnlyImport && root.remainingWatchOnlyAccountCapacity() === 0) {
            root.showLimitPopup(Constants.LimitWarning.WatchOnlyAccounts)
            return
        }

        if (root.remainingAccountCapacity() === 0) {
            root.showLimitPopup(Constants.LimitWarning.Accounts)
            return
        }

        root.currentState.doPrimaryAction()
    }

    function getSeedPhrase() {
        return root.addAccountModule.getSeedPhrase()
    }

    function changeSelectedOrigin(keyUid) {
        root.addAccountModule.changeSelectedOrigin(keyUid)
    }

    readonly property var validateEnsAsync: Backpressure.debounce(root, 500, function (name, uuid) {
        mainModule.resolveENS(name, uuid)
    });

    readonly property var changeDerivationPathPostponed: Backpressure.debounce(root, 400, function (path) {
        root.changeDerivationPath(path)
    })

    readonly property var changeWatchOnlyAccountAddressPostponed: Backpressure.debounce(root, 400, function (address) {
        root.addAccountModule.changeWatchOnlyAccountAddress(address)
    })

    function cleanWatchOnlyAccountAddress() {
        root.addAccountModule.changeWatchOnlyAccountAddress("")
    }

    changePrivateKeyPostponed: Backpressure.debounce(root, 400, function (privateKey) {
        root.addAccountModule.changePrivateKey(privateKey)
    })

    cleanPrivateKey: function() {
        root.enteredPrivateKeyIsValid = false
        root.addAccountModule.newKeyPairName = ""
        root.addAccountModule.changePrivateKey("")
    }

    function changeDerivationPath(path) {
        root.addAccountModule.changeDerivationPath(path)
    }

    function changeRootDerivationPath(rootPath) {
        root.selectedRootPath = rootPath
        root.addAccountModule.derivationPath = "%1/".arg(rootPath)
    }

    function changeSelectedDerivedAddress(address) {
        root.addAccountModule.changeSelectedDerivedAddress(address)
    }

    function resetDerivationPath() {
        root.selectedRootPath = Constants.addAccountPopup.predefinedPaths.ethereum
        root.addAccountModule.resetDerivationPath()
    }

    function authenticateForEditingDerivationPath() {
        root.addAccountModule.authenticateForEditingDerivationPath()
    }

    readonly property Connections _authRequestConnections: Connections {
        target: root.addAccountModule
        function onAuthenticationRequested(keyUid: string) {
            Global.openAuthenticationPopup(Constants.authenticationReason.addAccount, keyUid, false)
        }
    }

    readonly property Connections _authResultConnections: Connections {
        target: Global
        function onAuthenticationResult(reason: string, password: string, pin: string, keyUid: string) {
            if (reason !== Constants.authenticationReason.addAccount)
                return
            root.addAccountModule.authenticationCompleted(password, pin, keyUid)
        }
    }

    function startScanningForActivity() {
        root.addAccountModule.startScanningForActivity()
    }

    function isChecksumValidForAddress(address) {
        return root.addAccountModule.isChecksumValidForAddress(address)
    }

    function remainingAccountCapacity() {
        return root.addAccountModule.remainingAccountCapacity()
    }

    function remainingKeypairCapacity() {
        return root.addAccountModule.remainingKeypairCapacity()
    }

    function remainingWatchOnlyAccountCapacity() {
        return root.addAccountModule.remainingWatchOnlyAccountCapacity()
    }

    validSeedPhrase: function(seedPhrase) {
        return root.addAccountModule.validSeedPhrase(seedPhrase)
    }

    changeSeedPhrase: function(seedPhrase) {
        root.addAccountModule.changeSeedPhrase(seedPhrase)
    }

    function cleanSeedPhrase() {
        root.enteredSeedPhraseIsValid = false
        root.addAccountModule.newKeyPairName = ""
        root.changeSeedPhrase("")
    }

    function translation(key, isTitle) {
        if (!isTitle) {
            if (key === Constants.addAccountPopup.predefinedPaths.custom)
                return qsTr("Type your own derivation path")
            return key
        }
        switch(key) {
        case Constants.addAccountPopup.predefinedPaths.custom:
            return qsTr("Custom")
        case Constants.addAccountPopup.predefinedPaths.ethereum:
            return qsTr("Ethereum")
        case Constants.addAccountPopup.predefinedPaths.ethereumLedger:
            return qsTr("Ethereum (Ledger)")
        case Constants.addAccountPopup.predefinedPaths.ethereumLedgerLive:
            return qsTr("Ethereum (Ledger Live/KeepKey)")
        }
    }

    readonly property bool primaryPopupButtonEnabled: {
        if (!root.addAccountModule || !root.currentState || root.disablePopup) {
            return false
        }

        if (root.editMode) {
            return root.accountNameIsValid &&
                    root.addAccountModule.accountName !== root.getStoredAccountName() ||
                    root.addAccountModule.selectedColorId !== "" &&
                    root.addAccountModule.selectedColorId !== root.getStoredSelectedColorId() ||
                    root.addAccountModule.selectedEmoji !== "" &&
                    root.addAccountModule.selectedEmoji !== root.getStoredSelectedEmoji()
        }

        let valid = root.accountNameIsValid &&
            root.addAccountModule.selectedColorId !== "" &&
            root.addAccountModule.selectedEmoji !== ""

        if (root.currentState.stateType === Constants.addAccountPopup.state.main) {
            if(root.derivationPathEditingNotValid)
                return false

            if (root.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.profile ||
                    root.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.seedImport) {
                return valid &&
                        (!root.addAccountModule.actionAuthenticated ||
                        !!root.selectedDerivedAddress &&
                        root.selectedDerivedAddress.alreadyCreatedChecked &&
                        !root.selectedDerivedAddress.alreadyCreated &&
                        root.selectedDerivedAddress.address !== "") &&
                        root.derivationPathRegEx.test(root.addAccountModule.derivationPath) &&
                        (!root.derivationPathOutOfTheDefaultStatusDerivationTree ||
                         root.derivationPathOutOfTheDefaultStatusDerivationTreeConfirmed)
            }
            if (root.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.unknown &&
                    root.selectedOrigin.keyUid === Constants.appTranslatableConstants.addAccountLabelOptionAddWatchOnlyAcc) {
                return valid &&
                        !!root.watchOnlyAccAddress &&
                        root.watchOnlyAccAddress.alreadyCreatedChecked &&
                        !root.watchOnlyAccAddress.alreadyCreated &&
                        root.watchOnlyAccAddress.address !== ""
            }
            if (root.selectedOrigin.pairType === Constants.addAccountPopup.keyPairType.privateKeyImport) {
                return valid &&
                        root.enteredPrivateKeyIsValid &&
                        !!root.privateKeyAccAddress &&
                        root.privateKeyAccAddress.alreadyCreatedChecked &&
                        !root.privateKeyAccAddress.alreadyCreated &&
                        root.privateKeyAccAddress.address !== "" &&
                        root.addAccountModule.newKeyPairName.length >= Constants.addAccountPopup.keyPairAccountNameMinLength
            }
        }

        if (root.currentState.stateType === Constants.addAccountPopup.state.enterPrivateKey) {
            return root.enteredPrivateKeyIsValid &&
                    !!root.privateKeyAccAddress &&
                    root.privateKeyAccAddress.alreadyCreatedChecked &&
                    !root.privateKeyAccAddress.alreadyCreated &&
                    root.privateKeyAccAddress.address !== "" &&
                    root.addAccountModule.newKeyPairName.length >= Constants.addAccountPopup.keyPairAccountNameMinLength
        }

        if (root.currentState.stateType === Constants.addAccountPopup.state.enterSeedPhrase) {
            return root.enteredSeedPhraseIsValid &&
                    root.addAccountModule.newKeyPairName.length >= Constants.addAccountPopup.keyPairAccountNameMinLength

        }

        if (root.currentState.stateType === Constants.addAccountPopup.state.confirmAddingNewMasterKey) {
            return root.addingNewMasterKeyConfirmed
        }

        if (root.currentState.stateType === Constants.addAccountPopup.state.displaySeedPhrase) {
            return root.seedPhraseRevealed
        }

        if (root.currentState.stateType === Constants.addAccountPopup.state.enterSeedPhraseWord1) {
            return root.seedPhraseWord1Valid
        }

        if (root.currentState.stateType === Constants.addAccountPopup.state.enterSeedPhraseWord2) {
            return root.seedPhraseWord2Valid
        }

        if (root.currentState.stateType === Constants.addAccountPopup.state.confirmSeedPhraseBackup) {
            return root.seedPhraseBackupConfirmed
        }

        if (root.currentState.stateType === Constants.addAccountPopup.state.enterKeypairName) {
            return root.addAccountModule.newKeyPairName.length >= Constants.addAccountPopup.keyPairAccountNameMinLength
        }

        return true
    }
}
