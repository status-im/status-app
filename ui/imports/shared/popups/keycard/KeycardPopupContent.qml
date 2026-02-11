import QtQuick
import QtQuick.Controls

import utils

import "./states"

Control {
    id: root

    property string myKeyUid

    property var sharedKeycardModule
    property var emojiPopup
    readonly property alias primaryButtonEnabled: d.primaryButtonEnabled

    objectName: "KeycardSharedPopupContent"

    QtObject {
        id: d
        property bool primaryButtonEnabled: false
    }

    contentItem: Loader {
        id: loader
        anchors.fill: parent
        sourceComponent: {
            switch (root.sharedKeycardModule.currentState.stateType) {
            case Constants.keycardSharedState.keycardFlowStarted:
            case Constants.keycardSharedState.biometrics:
            case Constants.keycardSharedState.noPCSCService:
            case Constants.keycardSharedState.pluginReader:
            case Constants.keycardSharedState.insertKeycard:
            case Constants.keycardSharedState.keycardInserted:
            case Constants.keycardSharedState.readingKeycard:
            case Constants.keycardSharedState.keyPairMigrateSuccess:
            case Constants.keycardSharedState.keyPairMigrateFailure:
            case Constants.keycardSharedState.migrateKeypairToApp:
            case Constants.keycardSharedState.migrateKeypairToKeycard:
            case Constants.keycardSharedState.migratingKeypairToApp:
            case Constants.keycardSharedState.migratingKeypairToKeycard:
            case Constants.keycardSharedState.creatingAccountNewSeedPhraseSuccess:
            case Constants.keycardSharedState.creatingAccountNewSeedPhraseFailure:
            case Constants.keycardSharedState.creatingAccountNewSeedPhrase:
            case Constants.keycardSharedState.creatingAccountOldSeedPhraseSuccess:
            case Constants.keycardSharedState.creatingAccountOldSeedPhraseFailure:
            case Constants.keycardSharedState.creatingAccountOldSeedPhrase:
            case Constants.keycardSharedState.importingFromKeycardSuccess:
            case Constants.keycardSharedState.importingFromKeycardFailure:
            case Constants.keycardSharedState.importingFromKeycard:
            case Constants.keycardSharedState.keycardRenameSuccess:
            case Constants.keycardSharedState.keycardRenameFailure:
            case Constants.keycardSharedState.renamingKeycard:
            case Constants.keycardSharedState.changingKeycardPin:
            case Constants.keycardSharedState.changingKeycardPuk:
            case Constants.keycardSharedState.changingKeycardPukSuccess:
            case Constants.keycardSharedState.changingKeycardPukFailure:
            case Constants.keycardSharedState.changingKeycardPairingCode:
            case Constants.keycardSharedState.changingKeycardPairingCodeSuccess:
            case Constants.keycardSharedState.changingKeycardPairingCodeFailure:
            case Constants.keycardSharedState.factoryResetSuccess:
            case Constants.keycardSharedState.keycardEmptyMetadata:
            case Constants.keycardSharedState.keycardEmpty:
            case Constants.keycardSharedState.keycardNotEmpty:
            case Constants.keycardSharedState.keycardAlreadyUnlocked:
            case Constants.keycardSharedState.notKeycard:
            case Constants.keycardSharedState.unlockKeycardOptions:
            case Constants.keycardSharedState.unlockingKeycard:
            case Constants.keycardSharedState.unlockKeycardFailure:
            case Constants.keycardSharedState.unlockKeycardSuccess:
            case Constants.keycardSharedState.wrongKeycard:
            case Constants.keycardSharedState.biometricsReadyToSign:
            case Constants.keycardSharedState.maxPinRetriesReached:
            case Constants.keycardSharedState.maxPukRetriesReached:
            case Constants.keycardSharedState.maxPairingSlotsReached:
            case Constants.keycardSharedState.recognizedKeycard:
            case Constants.keycardSharedState.keycardMetadataDisplay:
            case Constants.keycardSharedState.biometricsPasswordFailed:
            case Constants.keycardSharedState.biometricsPinFailed:
            case Constants.keycardSharedState.biometricsPinInvalid:
            case Constants.keycardSharedState.removeKeycard:
            case Constants.keycardSharedState.sameKeycard:
            case Constants.keycardSharedState.copyToKeycard:
            case Constants.keycardSharedState.copyingKeycard:
            case Constants.keycardSharedState.copyingKeycardSuccess:
            case Constants.keycardSharedState.copyingKeycardFailure:
            case Constants.keycardSharedState.seedPhraseAlreadyInUse:
                return initComponent

            case Constants.keycardSharedState.factoryResetConfirmation:
            case Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata:
                return confirmationComponent

            case Constants.keycardSharedState.selectExistingKeyPair:
                return selectKeyPairComponent

            case Constants.keycardSharedState.createPin:
            case Constants.keycardSharedState.repeatPin:
            case Constants.keycardSharedState.enterPin:
            case Constants.keycardSharedState.wrongPin:
            case Constants.keycardSharedState.wrongKeychainPin:
            case Constants.keycardSharedState.changingKeycardPinSuccess:
            case Constants.keycardSharedState.changingKeycardPinFailure:
            case Constants.keycardSharedState.pinSet:
            case Constants.keycardSharedState.pinVerified:
                return keycardPinComponent

            case Constants.keycardSharedState.createPuk:
            case Constants.keycardSharedState.repeatPuk:
            case Constants.keycardSharedState.enterPuk:
            case Constants.keycardSharedState.wrongPuk:
                return keycardPukComponent

            case Constants.keycardSharedState.enterSeedPhrase:
            case Constants.keycardSharedState.wrongSeedPhrase:
                return enterSeedPhraseComponent

            case Constants.keycardSharedState.seedPhraseDisplay:
                return seedPhraseComponent

            case Constants.keycardSharedState.seedPhraseEnterWords:
                return enterSeedPhraseWordsComponent

            case Constants.keycardSharedState.enterPassword:
            case Constants.keycardSharedState.enterBiometricsPassword:
            case Constants.keycardSharedState.wrongBiometricsPassword:
            case Constants.keycardSharedState.wrongPassword:
                return passwordComponent

            case Constants.keycardSharedState.createPassword:
                return createPasswordComponent

            case Constants.keycardSharedState.confirmPassword:
                return confirmPasswordComponent

            case Constants.keycardSharedState.enterKeycardName:
                return enterNameComponent

            case Constants.keycardSharedState.manageKeycardAccounts:
                return manageAccountsComponent

            case Constants.keycardSharedState.createPairingCode:
                return enterPairingCodeComponent
            }

            return undefined
        }
    }

    Component {
        id: initComponent
        KeycardInit {
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = false
            }
        }
    }

    Component {
        id: confirmationComponent
        KeycardConfirmation {
            myKeyUid: root.myKeyUid
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = false
            }

            onConfirmationUpdated: {
                d.primaryButtonEnabled = value
            }
        }
    }

    Component {
        id: selectKeyPairComponent
        SelectKeyPair {
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = false
            }

            onKeyPairSelected: {
                d.primaryButtonEnabled = true
            }
        }
    }

    Component {
        id: keycardPinComponent
        KeycardPin {
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = false
            }

            onPinUpdated: function(pin) {
                d.primaryButtonEnabled = pin.length === Constants.keycard.general.keycardPinLength
            }
        }
    }

    Component {
        id: keycardPukComponent
        KeycardPuk {
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = false
            }

            onPukUpdated: {
                d.primaryButtonEnabled = puk.length === Constants.keycard.general.keycardPukLength
            }
        }
    }

    Component {
        id: enterSeedPhraseComponent
        EnterSeedPhrase {
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = false
            }

            onValidation: {
                d.primaryButtonEnabled = result
            }
        }
    }

    Component {
        id: seedPhraseComponent
        SeedPhrase {
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = seedPhraseRevealed
            }

            onSeedPhraseRevealedChanged: {
                d.primaryButtonEnabled = seedPhraseRevealed
            }
        }
    }

    Component {
        id: enterSeedPhraseWordsComponent
        EnterSeedPhraseWords {
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = false
            }

            onValidation: {
                d.primaryButtonEnabled = result
            }
        }
    }

    Component {
        id: passwordComponent
        EnterPassword {
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = false
            }

            onPasswordValid: {
                d.primaryButtonEnabled = valid
            }
        }
    }

    Component {
        id: createPasswordComponent
        CreatePassword {
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = false
            }

            onPasswordValid: {
                d.primaryButtonEnabled = valid
            }
        }
    }

    Component {
        id: confirmPasswordComponent
        ConfirmPassword {
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = false
            }

            onPasswordMatch: {
                d.primaryButtonEnabled = result
            }
        }
    }

    Component {
        id: enterNameComponent
        EnterName {
            sharedKeycardModule: root.sharedKeycardModule

            onValidation: {
                d.primaryButtonEnabled = result
            }
        }
    }

    Component {
        id: manageAccountsComponent
        ManageAccounts {
            sharedKeycardModule: root.sharedKeycardModule
            emojiPopup: root.emojiPopup

            onValidation: {
                d.primaryButtonEnabled = result
            }
        }
    }

    Component {
        id: enterPairingCodeComponent
        EnterPairingCode {
            sharedKeycardModule: root.sharedKeycardModule

            Component.onCompleted: {
                d.primaryButtonEnabled = false
            }

            onValidation: {
                d.primaryButtonEnabled = result
            }
        }
    }
}
