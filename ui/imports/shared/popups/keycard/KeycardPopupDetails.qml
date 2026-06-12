import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import utils

QtObject {
    id: root

    property var sharedKeycardModule

    property bool primaryButtonEnabled: false

    signal cancelBtnClicked()
    signal accountLimitWarning()

    // disables action buttons (back, cancel, primary, secondary) and close button (upper right "X" button) as well
    readonly property bool disableActionPopupButtons: {
        if (root.sharedKeycardModule.disablePopup) {
            return true
        }

        switch (root.sharedKeycardModule.currentState.stateType) {

        case Constants.keycardSharedState.keycardFlowStarted:
        case Constants.keycardSharedState.keycardInserted:
        case Constants.keycardSharedState.readingKeycard:
        case Constants.keycardSharedState.recognizedKeycard:
        case Constants.keycardSharedState.renamingKeycard:
        case Constants.keycardSharedState.unlockingKeycard:
        case Constants.keycardSharedState.changingKeycardPin:
        case Constants.keycardSharedState.changingKeycardPuk:
        case Constants.keycardSharedState.changingKeycardPairingCode:
        case Constants.keycardSharedState.migratingKeypairToApp:
        case Constants.keycardSharedState.migratingKeypairToKeycard:
        case Constants.keycardSharedState.creatingAccountNewSeedPhrase:
        case Constants.keycardSharedState.creatingAccountOldSeedPhrase:
        case Constants.keycardSharedState.importingFromKeycard:
        case Constants.keycardSharedState.copyingKeycard:
            return true
        }

        return false
    }

    // disables only close button (upper right "X" button)
    readonly property bool disableCloseButton: {
        switch (root.sharedKeycardModule.currentState.stateType) {

        case Constants.keycardSharedState.keyPairMigrateSuccess:
            return root.sharedKeycardModule.migratingProfileKeyPair()
        }

        return false
    }

    property list<Item> leftButtons: [
        StatusBackButton {
            id: backButton
            visible: root.sharedKeycardModule.currentState.displayBackButton
            enabled: !root.disableActionPopupButtons

            Layout.minimumWidth: implicitWidth

            onClicked: {
                root.sharedKeycardModule.currentState.doBackAction()
            }
        }
    ]

    property list<StatusBaseButton> rightButtons: [
        StatusButton {
            id: cancelButton
            height: Constants.keycard.general.footerButtonsHeight
            borderColor: Theme.palette.baseColor2
            normalColor: "transparent"
            text: qsTr("Cancel")
            visible: {
                if(SQUtils.Utils.isMobile) return false
                if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.noPCSCService) {
                    return true
                }

                switch (root.sharedKeycardModule.currentState.flowType) {

                case Constants.keycardSharedFlow.setupNewKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.selectExistingKeyPair:
                    case Constants.keycardSharedState.keycardNotEmpty:
                    case Constants.keycardSharedState.keycardEmptyMetadata:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                    case Constants.keycardSharedState.factoryResetSuccess:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.keycardNotEmpty:
                    case Constants.keycardSharedState.keycardEmptyMetadata:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.createPin:
                    case Constants.keycardSharedState.repeatPin:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                    case Constants.keycardSharedState.factoryResetSuccess:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.keycardNotEmpty:
                    case Constants.keycardSharedState.keycardEmptyMetadata:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.createPin:
                    case Constants.keycardSharedState.repeatPin:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                    case Constants.keycardSharedState.factoryResetSuccess:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                    case Constants.keycardSharedState.enterSeedPhrase:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.importFromKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.factoryReset:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                    case Constants.keycardSharedState.keycardEmptyMetadata:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                    case Constants.keycardSharedState.factoryResetConfirmation:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.authentication:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.wrongKeychainPin:
                    case Constants.keycardSharedState.biometricsReadyToSign:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.enterPassword:
                    case Constants.keycardSharedState.wrongPassword:
                    case Constants.keycardSharedState.biometricsPasswordFailed:
                    case Constants.keycardSharedState.biometricsPinFailed:
                    case Constants.keycardSharedState.biometricsPinInvalid:
                    case Constants.keycardSharedState.enterBiometricsPassword:
                    case Constants.keycardSharedState.wrongBiometricsPassword:
                    case Constants.keycardSharedState.enterPin:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.sign:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.wrongKeychainPin:
                    case Constants.keycardSharedState.biometricsReadyToSign:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.biometricsPinFailed:
                    case Constants.keycardSharedState.biometricsPinInvalid:
                    case Constants.keycardSharedState.enterPin:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.unlockKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.enterPuk:
                    case Constants.keycardSharedState.wrongPuk:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.unlockKeycardOptions:
                    case Constants.keycardSharedState.enterSeedPhrase:
                        return true
                    case Constants.keycardSharedState.maxPukRetriesReached:
                        // we're sure that we cannot unlock it from here using seed phrase and also in this point max num of puk retries is reached
                        // the only option to unlock a keycard is to run unlock flow from details view of the locked keycard
                        return root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.disableSeedPhraseForUnlock
                    }
                    break

                case Constants.keycardSharedFlow.displayKeycardContent:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.renameKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.changeKeycardPin:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.createPin:
                    case Constants.keycardSharedState.repeatPin:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.changeKeycardPuk:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.createPuk:
                    case Constants.keycardSharedState.repeatPuk:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.changePairingCode:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.createPairingCode:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return true
                    }
                    break

                case Constants.keycardSharedFlow.createCopyOfAKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                    case Constants.keycardSharedState.removeKeycard:
                    case Constants.keycardSharedState.sameKeycard:
                    case Constants.keycardSharedState.copyToKeycard:
                    case Constants.keycardSharedState.enterSeedPhrase:
                    case Constants.keycardSharedState.wrongSeedPhrase:
                    case Constants.keycardSharedState.keycardNotEmpty:
                        return true

                    case Constants.keycardSharedState.keycardEmptyMetadata:
                        let copyFromAKeycardPartDone = root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.copyFromAKeycardPartDone
                        if (copyFromAKeycardPartDone) {
                            return true
                        }
                        break
                    }
                    break

                case Constants.keycardSharedFlow.migrateFromKeycardToApp:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.migrateKeypairToApp:
                    case Constants.keycardSharedState.enterSeedPhrase:
                    case Constants.keycardSharedState.wrongSeedPhrase:
                    case Constants.keycardSharedState.createPassword:
                    case Constants.keycardSharedState.confirmPassword:
                        return !root.sharedKeycardModule.forceFlow
                    }
                    break
                }

                return false
            }
            enabled: !root.sharedKeycardModule.forceFlow && !root.disableActionPopupButtons
            onClicked: {
                root.cancelBtnClicked();
            }
        },

        StatusButton {
            id: secondaryButton
            height: Constants.keycard.general.footerButtonsHeight
            borderColor: Theme.palette.baseColor2
            normalColor: "transparent"
            text: {
                switch (root.sharedKeycardModule.currentState.flowType) {

                case Constants.keycardSharedFlow.authentication:
                    if (userProfile.usingBiometricLogin) {

                        switch (root.sharedKeycardModule.currentState.stateType) {

                        case Constants.keycardSharedState.enterPassword:
                        case Constants.keycardSharedState.wrongPassword:
                            return qsTr("Use biometrics")

                        case Constants.keycardSharedState.biometricsPasswordFailed:
                            return qsTr("Use password instead")

                        case Constants.keycardSharedState.enterPin:
                        case Constants.keycardSharedState.wrongPin:
                            return qsTr("Use biometrics")

                        case Constants.keycardSharedState.keycardFlowStarted:
                        case Constants.keycardSharedState.pluginReader:
                        case Constants.keycardSharedState.insertKeycard:
                        case Constants.keycardSharedState.keycardInserted:
                        case Constants.keycardSharedState.readingKeycard:
                        case Constants.keycardSharedState.biometricsReadyToSign:
                        case Constants.keycardSharedState.notKeycard:
                        case Constants.keycardSharedState.biometricsPinFailed:
                        case Constants.keycardSharedState.wrongKeycard:
                        case Constants.keycardSharedState.keycardEmpty:
                            return qsTr("Use PIN")

                        case Constants.keycardSharedState.biometricsPinInvalid:
                            return qsTr("Update PIN")
                        }
                    }
                    break

                case Constants.keycardSharedFlow.sign:
                    if (userProfile.usingBiometricLogin) {

                        switch (root.sharedKeycardModule.currentState.stateType) {

                        case Constants.keycardSharedState.enterPin:
                        case Constants.keycardSharedState.wrongPin:
                            return qsTr("Use biometrics")

                        case Constants.keycardSharedState.keycardFlowStarted:
                        case Constants.keycardSharedState.pluginReader:
                        case Constants.keycardSharedState.insertKeycard:
                        case Constants.keycardSharedState.keycardInserted:
                        case Constants.keycardSharedState.readingKeycard:
                        case Constants.keycardSharedState.biometricsReadyToSign:
                        case Constants.keycardSharedState.notKeycard:
                        case Constants.keycardSharedState.biometricsPinFailed:
                        case Constants.keycardSharedState.wrongKeycard:
                        case Constants.keycardSharedState.keycardEmpty:
                            return qsTr("Use PIN")

                        case Constants.keycardSharedState.biometricsPinInvalid:
                            return qsTr("Update PIN")
                        }
                    }
                    break

                case Constants.keycardSharedFlow.unlockKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.unlockKeycardOptions:
                        if (root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.disableSeedPhraseForUnlock &&
                                !(root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.offerPukForUnlock)) {
                            // In case max puk retries or free pairing slots is reached and user is running unlock flow from a flow
                            // where we cannot determine key pair, than we should should display only "Close" button and inform him
                            // to run unlock flow directly.
                            return ""
                        }
                        return qsTr("Unlock using PUK")
                    }
                    break

                case Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.manageKeycardAccounts:
                        return qsTr("Add another account")
                    }
                    break

                case Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.manageKeycardAccounts:
                        return qsTr("Add another account")

                    case Constants.keycardSharedState.seedPhraseAlreadyInUse:
                        return qsTr("View accounts in Wallet")
                    }
                    break

                case Constants.keycardSharedFlow.importFromKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.seedPhraseAlreadyInUse:
                        return qsTr("View accounts in Wallet")

                    case Constants.keycardSharedState.importingFromKeycardSuccess:
                        return qsTr("View imported accounts in Wallet")
                    }
                    break

                case Constants.keycardSharedFlow.migrateFromKeycardToApp:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.biometrics:
                        return qsTr("I prefer to use my password")

                    case Constants.keycardSharedState.keyPairMigrateSuccess:
                        if (!root.sharedKeycardModule.migratingProfileKeyPair())
                            return qsTr("Factory reset this Keycard")
                    }
                    break

                case Constants.keycardSharedFlow.migrateFromAppToKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.biometrics:
                        return qsTr("I prefer to use my PIN")
                    }
                    break
                }

                return ""
            }

            visible: text !== ""
            enabled: {
                if (root.disableActionPopupButtons) {
                    return false
                }

                switch (root.sharedKeycardModule.currentState.flowType) {

                case Constants.keycardSharedFlow.authentication:
                    if (userProfile.usingBiometricLogin) {
                        switch (root.sharedKeycardModule.currentState.stateType) {
                        case Constants.keycardSharedState.pluginReader:
                        case Constants.keycardSharedState.insertKeycard:
                        case Constants.keycardSharedState.notKeycard:
                        case Constants.keycardSharedState.wrongKeycard:
                        case Constants.keycardSharedState.keycardEmpty:
                            return false
                        }
                    }
                    break

                case Constants.keycardSharedFlow.sign:
                    if (userProfile.usingBiometricLogin) {
                        switch (root.sharedKeycardModule.currentState.stateType) {
                        case Constants.keycardSharedState.pluginReader:
                        case Constants.keycardSharedState.insertKeycard:
                        case Constants.keycardSharedState.notKeycard:
                        case Constants.keycardSharedState.wrongKeycard:
                        case Constants.keycardSharedState.keycardEmpty:
                            return false
                        }
                    }
                    break

                case Constants.keycardSharedFlow.unlockKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.unlockKeycardOptions:
                        return root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.offerPukForUnlock
                    }
                    break

                case Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.manageKeycardAccounts:
                        return root.primaryButtonEnabled
                    }
                    break

                case Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.manageKeycardAccounts:
                        return root.primaryButtonEnabled
                    }
                    break
                }

                return true
            }

            onClicked: {
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase ||
                        root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase) {

                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.manageKeycardAccounts &&
                            !!root.sharedKeycardModule.keyPairForProcessing &&
                            root.sharedKeycardModule.remainingAccountCapacity() === root.sharedKeycardModule.keyPairForProcessing.accounts.count) {
                        root.accountLimitWarning()
                        return
                    }
                }

                root.sharedKeycardModule.currentState.doSecondaryAction()
            }
        },

        StatusButton {
            id: primaryButton
            objectName: "PrimaryButton"
            height: Constants.keycard.general.footerButtonsHeight
            text: {
                if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.noPCSCService) {
                    return qsTr("Retry")
                }

                switch (root.sharedKeycardModule.currentState.flowType) {

                case Constants.keycardSharedFlow.setupNewKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.createPin:
                    case Constants.keycardSharedState.repeatPin:
                    case Constants.keycardSharedState.pinSet:
                        return qsTr("Input recovery phrase")

                    case Constants.keycardSharedState.seedPhraseEnterWords:
                        return qsTr("Yes, migrate key pair to this Keycard")

                    case Constants.keycardSharedState.enterSeedPhrase:
                        return qsTr("Yes, migrate key pair to Keycard")

                    case Constants.keycardSharedState.wrongSeedPhrase:
                        return qsTr("Try entering recovery phrase again")

                    case Constants.keycardSharedState.keycardNotEmpty:
                        return qsTr("Check what is stored on this Keycard")

                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                        return qsTr("I don’t know the PIN")

                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                        return qsTr("Factory reset this Keycard")

                    case Constants.keycardSharedState.selectExistingKeyPair:
                    case Constants.keycardSharedState.keycardEmptyMetadata:
                    case Constants.keycardSharedState.factoryResetSuccess:
                    case Constants.keycardSharedState.seedPhraseDisplay:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                        return qsTr("Next")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        if (root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.disableSeedPhraseForUnlock)
                            return qsTr("Unlock Keycard")
                        return qsTr("Next")

                    case Constants.keycardSharedState.migratingKeypairToKeycard:
                        return qsTr("Done")

                    case Constants.keycardSharedState.keyPairMigrateFailure:
                        return qsTr("Close app")

                    case Constants.keycardSharedState.keyPairMigrateSuccess:
                        if (root.sharedKeycardModule.migratingProfileKeyPair())
                            return qsTr("Restart app & sign in using your new Keycard")
                        return qsTr("Done")

                    }
                    break

                case Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardNotEmpty:
                        return qsTr("Check what is stored on this Keycard")

                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                        return qsTr("I don’t know the PIN")

                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                        return qsTr("Factory reset this Keycard")

                    case Constants.keycardSharedState.keycardEmptyMetadata:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                    case Constants.keycardSharedState.factoryResetSuccess:
                    case Constants.keycardSharedState.seedPhraseDisplay:
                    case Constants.keycardSharedState.seedPhraseEnterWords:
                    case Constants.keycardSharedState.createPin:
                    case Constants.keycardSharedState.repeatPin:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.pinSet:
                    case Constants.keycardSharedState.enterKeycardName:
                        return qsTr("Next")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        if (root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.disableSeedPhraseForUnlock)
                            return qsTr("Unlock Keycard")
                        return qsTr("Next")

                    case Constants.keycardSharedState.creatingAccountNewSeedPhrase:
                    case Constants.keycardSharedState.creatingAccountNewSeedPhraseSuccess:
                    case Constants.keycardSharedState.creatingAccountNewSeedPhraseFailure:
                        return qsTr("Done")

                    case Constants.keycardSharedState.manageKeycardAccounts:
                        return qsTr("Finalise Keycard")
                    }
                    break

                case Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.keycardNotEmpty:
                        return qsTr("Check what is stored on this Keycard")

                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                        return qsTr("I don’t know the PIN")

                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                        return qsTr("Factory reset this Keycard")

                    case Constants.keycardSharedState.keycardEmptyMetadata:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                    case Constants.keycardSharedState.factoryResetSuccess:
                    case Constants.keycardSharedState.createPin:
                    case Constants.keycardSharedState.repeatPin:
                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.pinSet:
                    case Constants.keycardSharedState.enterKeycardName:
                    case Constants.keycardSharedState.enterSeedPhrase:
                        return qsTr("Next")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        if (root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.disableSeedPhraseForUnlock)
                            return qsTr("Unlock Keycard")
                        return qsTr("Next")

                    case Constants.keycardSharedState.creatingAccountOldSeedPhrase:
                    case Constants.keycardSharedState.creatingAccountOldSeedPhraseSuccess:
                    case Constants.keycardSharedState.creatingAccountOldSeedPhraseFailure:
                    case Constants.keycardSharedState.seedPhraseAlreadyInUse:
                        return qsTr("Done")

                    case Constants.keycardSharedState.manageKeycardAccounts:
                        return qsTr("Finalise Keycard")
                    }
                    break

                case Constants.keycardSharedFlow.importFromKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.keycardEmpty:
                    case Constants.keycardSharedState.keycardEmptyMetadata:
                    case Constants.keycardSharedState.seedPhraseAlreadyInUse:
                        return qsTr("Done")

                    case Constants.keycardSharedState.keycardMetadataDisplay:
                        return qsTr("Name accounts")

                    case Constants.keycardSharedState.wrongPin:
                        return qsTr("I don’t know the PIN")

                    case Constants.keycardSharedState.pinVerified:
                        return qsTr("Next")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return qsTr("Unlock Keycard")

                    case Constants.keycardSharedState.manageKeycardAccounts:
                        if (root.sharedKeycardModule.keyPairHelper.accounts.count === root.sharedKeycardModule.keyPairForProcessing.accounts.count) {
                            return qsTr("Finalise import")
                        }
                        return qsTr("Next account")

                    case Constants.keycardSharedState.importingFromKeycard:
                    case Constants.keycardSharedState.importingFromKeycardSuccess:
                    case Constants.keycardSharedState.importingFromKeycardFailure:
                        return qsTr("Done")
                    }
                    break

                case Constants.keycardSharedFlow.factoryReset:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                        return qsTr("I don’t know the PIN")

                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                        return qsTr("Factory reset this Keycard")

                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                    case Constants.keycardSharedState.keycardEmptyMetadata:
                        return qsTr("Next")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return qsTr("Unlock Keycard")

                    case Constants.keycardSharedState.keycardEmpty:
                    case Constants.keycardSharedState.factoryResetSuccess:
                    case Constants.keycardSharedState.wrongKeycard:
                        return qsTr("Done")
                    }
                    break

                case Constants.keycardSharedFlow.authentication:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.biometricsReadyToSign:
                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.enterPassword:
                    case Constants.keycardSharedState.wrongPassword:
                    case Constants.keycardSharedState.enterPin:
                        return qsTr("Authenticate")

                    case Constants.keycardSharedState.keycardEmpty:
                        return qsTr("Done")

                    case Constants.keycardSharedState.enterBiometricsPassword:
                    case Constants.keycardSharedState.wrongBiometricsPassword:
                        return qsTr("Update password & authenticate")

                    case Constants.keycardSharedState.wrongKeychainPin:
                        return qsTr("Update PIN & authenticate")

                    case Constants.keycardSharedState.biometricsPasswordFailed:
                    case Constants.keycardSharedState.biometricsPinFailed:
                    case Constants.keycardSharedState.biometricsPinInvalid:
                        return qsTr("Retry biometrics")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return qsTr("Unlock Keycard")

                    }
                    break

                case Constants.keycardSharedFlow.sign:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.keycardFlowStarted:
                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.readingKeycard:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.keycardInserted:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.biometricsReadyToSign:
                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.enterPin:
                        return qsTr("Sign")

                    case Constants.keycardSharedState.keycardEmpty:
                        return qsTr("Done")

                    case Constants.keycardSharedState.wrongKeychainPin:
                        return qsTr("Update PIN & authenticate")

                    case Constants.keycardSharedState.biometricsPinFailed:
                    case Constants.keycardSharedState.biometricsPinInvalid:
                        return qsTr("Retry biometrics")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return qsTr("Unlock Keycard")

                    }
                    break

                case Constants.keycardSharedFlow.unlockKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.keycardEmpty:
                    case Constants.keycardSharedState.keycardEmptyMetadata:
                    case Constants.keycardSharedState.keycardAlreadyUnlocked:
                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.unlockingKeycard:
                    case Constants.keycardSharedState.unlockKeycardFailure:
                    case Constants.keycardSharedState.unlockKeycardSuccess:
                        return qsTr("Done")

                    case Constants.keycardSharedState.unlockKeycardOptions:
                        if (root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.disableSeedPhraseForUnlock &&
                                !(root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.offerPukForUnlock)) {
                            // In case max puk retries or free pairing slots is reached and user is running unlock flow from a flow
                            // where we cannot determine key pair, than we should should display only "Close" button and inform him
                            // to run unlock flow directly.
                            return ""
                        }
                        return qsTr("Unlock using recovery phrase")

                    case Constants.keycardSharedState.createPin:
                    case Constants.keycardSharedState.repeatPin:
                    case Constants.keycardSharedState.pinSet:
                    case Constants.keycardSharedState.enterSeedPhrase:
                    case Constants.keycardSharedState.enterPuk:
                    case Constants.keycardSharedState.wrongPuk:
                        return qsTr("Next")

                    case Constants.keycardSharedState.wrongSeedPhrase:
                        return qsTr("Try entering recovery phrase again")

                    case Constants.keycardSharedState.maxPukRetriesReached:
                        if (root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.disableSeedPhraseForUnlock) {
                            return ""
                        }
                        return qsTr("Unlock Keycard")

                    }
                    break

                case Constants.keycardSharedFlow.displayKeycardContent:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.keycardEmpty:
                    case Constants.keycardSharedState.keycardEmptyMetadata:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                        return qsTr("Done")

                    case Constants.keycardSharedState.wrongPin:
                        return qsTr("I don’t know the PIN")

                    case Constants.keycardSharedState.pinVerified:
                        return qsTr("Next")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return qsTr("Unlock Keycard")

                    }
                    break

                case Constants.keycardSharedFlow.renameKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.keycardEmptyMetadata:
                    case Constants.keycardSharedState.keycardRenameSuccess:
                    case Constants.keycardSharedState.keycardRenameFailure:
                    case Constants.keycardSharedState.renamingKeycard:
                        return qsTr("Done")

                    case Constants.keycardSharedState.wrongPin:
                        return qsTr("I don’t know the PIN")

                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                        return qsTr("Next")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return qsTr("Unlock Keycard")

                    case Constants.keycardSharedState.enterKeycardName:
                        return qsTr("Rename this Keycard")
                    }
                    break

                case Constants.keycardSharedFlow.changeKeycardPin:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.changingKeycardPin:
                    case Constants.keycardSharedState.changingKeycardPinSuccess:
                    case Constants.keycardSharedState.changingKeycardPinFailure:
                        return qsTr("Done")

                    case Constants.keycardSharedState.wrongPin:
                        return qsTr("I don’t know the PIN")

                    case Constants.keycardSharedState.pinVerified:
                        return qsTr("Next")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return qsTr("Unlock Keycard")
                    }
                    break

                case Constants.keycardSharedFlow.changeKeycardPuk:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.changingKeycardPuk:
                    case Constants.keycardSharedState.changingKeycardPukSuccess:
                    case Constants.keycardSharedState.changingKeycardPukFailure:
                        return qsTr("Done")

                    case Constants.keycardSharedState.wrongPin:
                        return qsTr("I don’t know the PIN")

                    case Constants.keycardSharedState.pinVerified:
                        return qsTr("Next")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return qsTr("Unlock Keycard")
                    }
                    break

                case Constants.keycardSharedFlow.changePairingCode:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.changingKeycardPairingCode:
                    case Constants.keycardSharedState.changingKeycardPairingCodeSuccess:
                    case Constants.keycardSharedState.changingKeycardPairingCodeFailure:
                        return qsTr("Done")

                    case Constants.keycardSharedState.wrongPin:
                        return qsTr("I don’t know the PIN")

                    case Constants.keycardSharedState.pinVerified:
                        return qsTr("Next")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return qsTr("Unlock Keycard")

                    case Constants.keycardSharedState.createPairingCode:
                        return qsTr("Set paring code")
                    }
                    break

                case Constants.keycardSharedFlow.createCopyOfAKeycard:
                    let copyFromAKeycardPartDone = root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.copyFromAKeycardPartDone
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.enterPin:
                    case Constants.keycardSharedState.wrongPin:
                        if (copyFromAKeycardPartDone) {
                            return qsTr("I don’t know the PIN")
                        }
                        break

                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.keycardEmpty:
                    case Constants.keycardSharedState.copyingKeycard:
                    case Constants.keycardSharedState.copyingKeycardSuccess:
                    case Constants.keycardSharedState.copyingKeycardFailure:
                        return qsTr("Done")

                    case Constants.keycardSharedState.pinVerified:
                    case Constants.keycardSharedState.keycardMetadataDisplay:
                    case Constants.keycardSharedState.removeKeycard:
                    case Constants.keycardSharedState.factoryResetSuccess:
                    case Constants.keycardSharedState.copyToKeycard:
                    case Constants.keycardSharedState.enterSeedPhrase:
                        return qsTr("Next")

                    case Constants.keycardSharedState.keycardEmptyMetadata:
                        if (copyFromAKeycardPartDone) {
                            return qsTr("Next")
                        }
                        return qsTr("Done")

                    case Constants.keycardSharedState.wrongSeedPhrase:
                        return qsTr("Try entering recovery phrase again")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return qsTr("Unlock Keycard")

                    case Constants.keycardSharedState.sameKeycard:
                        return qsTr("Try inserting a different Keycard")

                    case Constants.keycardSharedState.notKeycard:
                        if (copyFromAKeycardPartDone) {
                            return qsTr("Try inserting a different Keycard")
                        }
                        break

                    case Constants.keycardSharedState.keycardNotEmpty:
                        return qsTr("Check what is stored on this Keycard")

                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                        return qsTr("Factory reset this Keycard")
                    }
                    break

                case Constants.keycardSharedFlow.migrateFromKeycardToApp:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.migrateKeypairToApp:
                    case Constants.keycardSharedState.enterSeedPhrase:
                    case Constants.keycardSharedState.wrongSeedPhrase:
                        return qsTr("Next")

                    case Constants.keycardSharedState.migratingKeypairToApp:
                        return qsTr("Done")

                    case Constants.keycardSharedState.createPassword:
                        return qsTr("Create Password")

                    case Constants.keycardSharedState.confirmPassword:
                        return qsTr("Finalize Status Password Creation")

                    case Constants.keycardSharedState.keyPairMigrateFailure:
                        return qsTr("Close App")

                    case Constants.keycardSharedState.biometrics:
                        return qsTr("Yes, use Touch ID")

                    case Constants.keycardSharedState.keyPairMigrateSuccess:
                        if (root.sharedKeycardModule.migratingProfileKeyPair())
                            return qsTr("Restart App & Sign In Using Your New Password")
                        return qsTr("Done")
                    }
                    break

                case Constants.keycardSharedFlow.migrateFromAppToKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {
                    case Constants.keycardSharedState.migrateKeypairToKeycard:
                    case Constants.keycardSharedState.pinVerified:
                        return qsTr("Next")

                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.keycardEmpty:
                    case Constants.keycardSharedState.keycardEmptyMetadata:
                        return qsTr("Try again")

                    case Constants.keycardSharedState.maxPinRetriesReached:
                    case Constants.keycardSharedState.maxPukRetriesReached:
                    case Constants.keycardSharedState.maxPairingSlotsReached:
                        return qsTr("Unlock Keycard")

                    case Constants.keycardSharedState.biometrics:
                        return qsTr("Yes, use Touch ID")

                    case Constants.keycardSharedState.keyPairMigrateFailure:
                        return qsTr("Close App")

                    case Constants.keycardSharedState.keyPairMigrateSuccess:
                        return qsTr("Restart App & Sign In Using Your Keycard")
                    }
                    break
                }

                return ""
            }
            visible: text !== ""
            enabled: {
                if (root.disableActionPopupButtons) {
                    return false
                }

                switch (root.sharedKeycardModule.currentState.flowType) {
                case Constants.keycardSharedFlow.setupNewKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.selectExistingKeyPair:
                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                    case Constants.keycardSharedState.seedPhraseDisplay:
                    case Constants.keycardSharedState.seedPhraseEnterWords:
                    case Constants.keycardSharedState.enterSeedPhrase:
                        return root.primaryButtonEnabled

                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.recognizedKeycard:
                    case Constants.keycardSharedState.createPin:
                    case Constants.keycardSharedState.repeatPin:
                        return false
                    }
                    break

                case Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                    case Constants.keycardSharedState.seedPhraseDisplay:
                    case Constants.keycardSharedState.seedPhraseEnterWords:
                    case Constants.keycardSharedState.enterKeycardName:
                    case Constants.keycardSharedState.manageKeycardAccounts:
                        return root.primaryButtonEnabled

                    case Constants.keycardSharedState.createPin:
                    case Constants.keycardSharedState.repeatPin:
                        return false
                    }
                    break

                case Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                    case Constants.keycardSharedState.enterKeycardName:
                    case Constants.keycardSharedState.manageKeycardAccounts:
                    case Constants.keycardSharedState.enterSeedPhrase:
                        return root.primaryButtonEnabled

                    case Constants.keycardSharedState.createPin:
                    case Constants.keycardSharedState.repeatPin:
                        return false
                    }
                    break

                case Constants.keycardSharedFlow.importFromKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.keycardMetadataDisplay:
                        return root.sharedKeycardModule.keyPairHelper.accounts.count <= root.sharedKeycardModule.remainingAccountCapacity()

                    case Constants.keycardSharedState.manageKeycardAccounts:
                        return root.primaryButtonEnabled
                    }
                    break

                case Constants.keycardSharedFlow.factoryReset:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                        return root.primaryButtonEnabled
                    }
                    break

                case Constants.keycardSharedFlow.authentication:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.wrongKeychainPin:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.enterPassword:
                    case Constants.keycardSharedState.wrongPassword:
                    case Constants.keycardSharedState.enterBiometricsPassword:
                    case Constants.keycardSharedState.wrongBiometricsPassword:
                    case Constants.keycardSharedState.enterPin:
                        return root.primaryButtonEnabled
                    }
                    break

                case Constants.keycardSharedFlow.sign:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.pluginReader:
                    case Constants.keycardSharedState.insertKeycard:
                    case Constants.keycardSharedState.wrongPin:
                    case Constants.keycardSharedState.wrongKeychainPin:
                    case Constants.keycardSharedState.notKeycard:
                    case Constants.keycardSharedState.wrongKeycard:
                    case Constants.keycardSharedState.enterPin:
                        return root.primaryButtonEnabled
                    }
                    break

                case Constants.keycardSharedFlow.unlockKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.enterSeedPhrase:
                    case Constants.keycardSharedState.enterPuk:
                    case Constants.keycardSharedState.wrongPuk:
                        return root.primaryButtonEnabled

                    case Constants.keycardSharedState.createPin:
                    case Constants.keycardSharedState.repeatPin:
                        return false

                    case Constants.keycardSharedState.unlockKeycardOptions:
                        return !(root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.disableSeedPhraseForUnlock)
                    }
                    break

                case Constants.keycardSharedFlow.renameKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.enterKeycardName:
                        return root.primaryButtonEnabled
                    }
                    break

                case Constants.keycardSharedFlow.changePairingCode:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.createPairingCode:
                        return root.primaryButtonEnabled
                    }
                    break

                case Constants.keycardSharedFlow.createCopyOfAKeycard:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.factoryResetConfirmation:
                    case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                    case Constants.keycardSharedState.enterSeedPhrase:
                        return root.primaryButtonEnabled
                    }
                    break

                case Constants.keycardSharedFlow.migrateFromKeycardToApp:
                    switch (root.sharedKeycardModule.currentState.stateType) {

                    case Constants.keycardSharedState.enterSeedPhrase:
                    case Constants.keycardSharedState.createPassword:
                    case Constants.keycardSharedState.confirmPassword:
                        return root.primaryButtonEnabled
                    }
                    break
                }

                return true
            }

            icon.name: {
                switch (root.sharedKeycardModule.currentState.flowType) {
                case Constants.keycardSharedFlow.setupNewKeycard:
                    if (root.sharedKeycardModule.migratingProfileKeyPair()) {
                        switch (root.sharedKeycardModule.currentState.stateType) {

                        case Constants.keycardSharedState.seedPhraseEnterWords:
                        case Constants.keycardSharedState.enterSeedPhrase:
                            if (userProfile.usingBiometricLogin)
                                return "touch-id"
                            if (userProfile.migratedToColdWallet)
                                return "keycard"
                            return "password"
                        }
                    }
                    break

                case Constants.keycardSharedFlow.authentication:
                    if (userProfile.usingBiometricLogin) {
                        switch (root.sharedKeycardModule.currentState.stateType) {

                        case Constants.keycardSharedState.keycardFlowStarted:
                        case Constants.keycardSharedState.pluginReader:
                        case Constants.keycardSharedState.insertKeycard:
                        case Constants.keycardSharedState.keycardInserted:
                        case Constants.keycardSharedState.readingKeycard:
                        case Constants.keycardSharedState.biometricsPasswordFailed:
                        case Constants.keycardSharedState.biometricsPinFailed:
                        case Constants.keycardSharedState.biometricsPinInvalid:
                        case Constants.keycardSharedState.biometricsReadyToSign:
                        case Constants.keycardSharedState.notKeycard:
                        case Constants.keycardSharedState.wrongKeycard:
                            return "touch-id"
                        }
                    }
                    break

                case Constants.keycardSharedFlow.sign:
                    if (userProfile.usingBiometricLogin) {
                        switch (root.sharedKeycardModule.currentState.stateType) {

                        case Constants.keycardSharedState.keycardFlowStarted:
                        case Constants.keycardSharedState.pluginReader:
                        case Constants.keycardSharedState.insertKeycard:
                        case Constants.keycardSharedState.keycardInserted:
                        case Constants.keycardSharedState.readingKeycard:
                        case Constants.keycardSharedState.biometricsPinFailed:
                        case Constants.keycardSharedState.biometricsPinInvalid:
                        case Constants.keycardSharedState.biometricsReadyToSign:
                        case Constants.keycardSharedState.notKeycard:
                        case Constants.keycardSharedState.wrongKeycard:
                            return "touch-id"
                        }
                    }
                    break
                }

                return ""
            }

            onClicked: {
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase ||
                        root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase) {

                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.manageKeycardAccounts &&
                            !!root.sharedKeycardModule.keyPairForProcessing &&
                            root.sharedKeycardModule.remainingAccountCapacity() - root.sharedKeycardModule.keyPairForProcessing.accounts.count < 0) {
                        root.accountLimitWarning()
                        return
                    }
                }
                root.sharedKeycardModule.currentState.doPrimaryAction()
            }
        }
    ]
}
