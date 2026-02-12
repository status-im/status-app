import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

import utils

import "../helpers"

Control {
    id: root

    property var sharedKeycardModule

    onStateChanged: {
        if (state != d.processingStateName) {
            return
        }

        if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToKeycard ||
                root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToApp ||
                root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhrase ||
                root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhrase ||
                root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycard ||
                root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.renamingKeycard ||
                root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.unlockingKeycard ||
                root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycard) {
            root.sharedKeycardModule.currentState.doPrimaryAction()
        }
    }

    QtObject {
        id: d

        readonly property string processingStateName: "processing"
        readonly property string processingSuccessStateName: "processing-success"
        readonly property string processingFailureStateName: "processing-failure"

        readonly property bool hideKeyPair: root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.hideKeyPair
        readonly property bool copyFromAKeycardPartDone: root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.copyFromAKeycardPartDone
        readonly property bool authenticationOrSigning: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.authentication ||
                                                        root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.sign
    }

    Timer {
        id: timer
        interval: 1000
        running: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                 root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPin ||
                 root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPuk ||
                 root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPairingCode
        onTriggered: {
            root.sharedKeycardModule.currentState.doSecondaryAction()
        }
    }

    Component {
        id: keyPairForProcessingComponent
        KeyPairItem {
            keyPairType:  root.sharedKeycardModule.keyPairForProcessing.pairType
            keyPairKeyUid: root.sharedKeycardModule.keyPairForProcessing.keyUid
            keyPairName: root.sharedKeycardModule.keyPairForProcessing.name
            keyPairIcon: root.sharedKeycardModule.keyPairForProcessing.icon
            keyPairImage: root.sharedKeycardModule.keyPairForProcessing.image
            keyPairDerivedFrom: root.sharedKeycardModule.keyPairForProcessing.derivedFrom
            keyPairAccounts: root.sharedKeycardModule.keyPairForProcessing.accounts
            keyPairCardLocked: root.sharedKeycardModule.keyPairForProcessing.locked
            displayAdditionalInfoForProfileKeypair: root.sharedKeycardModule.currentState.flowType !== Constants.keycardSharedFlow.migrateFromKeycardToApp &&
                                                    root.sharedKeycardModule.currentState.flowType !== Constants.keycardSharedFlow.migrateFromAppToKeycard
        }
    }

    Component {
        id: unknownKeyPairCompontnt
        KeyPairUnknownItem {
            keyPairKeyUid: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard?
                               root.sharedKeycardModule.keyPairHelper.keyUid
                             : root.sharedKeycardModule.keyPairForProcessing.keyUid
            keyPairName: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard?
                             root.sharedKeycardModule.keyPairHelper.name
                           : root.sharedKeycardModule.keyPairForProcessing.name
            keyPairIcon: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard?
                             root.sharedKeycardModule.keyPairHelper.icon
                           : root.sharedKeycardModule.keyPairForProcessing.icon
            keyPairImage: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard?
                              root.sharedKeycardModule.keyPairHelper.image
                            : root.sharedKeycardModule.keyPairForProcessing.image
            keyPairDerivedFrom: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard?
                                    root.sharedKeycardModule.keyPairHelper.derivedFrom
                                  : root.sharedKeycardModule.keyPairForProcessing.derivedFrom
            keyPairCardLocked: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard?
                                 root.sharedKeycardModule.keyPairHelper.locked
                               : root.sharedKeycardModule.keyPairForProcessing.locked
            keyPairAccounts: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard?
                                 root.sharedKeycardModule.keyPairHelper.accounts
                               : root.sharedKeycardModule.keyPairForProcessing.accounts
        }
    }

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        id: layout
        spacing: Theme.padding

        KeycardImage {
            id: image
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Constants.keycard.shared.imageHeight
            Layout.preferredWidth: Constants.keycard.shared.imageWidth
            visible: pattern != "" || source != ""

            onAnimationCompleted: {
                if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                        root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard) {
                    root.sharedKeycardModule.currentState.doSecondaryAction()
                }
            }
        }

        ColumnLayout {
            spacing: Theme.halfPadding
            Layout.fillWidth: true

            StatusIcon {
                id: icon
                Layout.alignment: Qt.AlignCenter
                visible: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard
                width: Theme.padding
                height: Theme.padding
                icon: "checkmark"
                color: Theme.palette.baseColor1
            }
            StatusLoadingIndicator {
                id: loading
                Layout.alignment: Qt.AlignCenter
                visible: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                         root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToKeycard ||
                         root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToApp ||
                         root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhrase ||
                         root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhrase ||
                         root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycard ||
                         root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.renamingKeycard ||
                         root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.unlockingKeycard ||
                         root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPin ||
                         root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPuk ||
                         root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPairingCode ||
                         root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycard
            }
            TitleText {
                id: title
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }

        StatusBaseText {
            id: message
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Loader {
            id: loader
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            active: {
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard) {
                    if((root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pluginReader && !d.hideKeyPair) ||
                            (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard && !d.hideKeyPair) ||
                            (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted && !d.hideKeyPair) ||
                            (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard && !d.hideKeyPair) ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateFailure ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhrase ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhraseSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhraseFailure) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhrase ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhraseSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhraseFailure ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.seedPhraseAlreadyInUse) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycardSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycardFailure ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.seedPhraseAlreadyInUse) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.factoryReset) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay) {
                        return true
                    }
                    if(!!root.sharedKeycardModule.keyPairForProcessing &&
                            (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                             root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                             root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                             root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                             root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard))
                        return true
                }
                if (d.authenticationOrSigning &&
                        !!root.sharedKeycardModule.keyPairForProcessing &&
                        root.sharedKeycardModule.keyPairForProcessing.name !== "") {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardEmpty ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.biometricsReadyToSign ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.biometricsPinFailed ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.biometricsPinInvalid ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.displayKeycardContent) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.renameKeycard && !d.hideKeyPair) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardRenameSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardRenameFailure)
                        return true
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPin && !d.hideKeyPair) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard)
                        return true
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPuk && !d.hideKeyPair) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard)
                        return true
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changePairingCode && !d.hideKeyPair) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard)
                        return true
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard && !d.hideKeyPair) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.removeKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyToKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycardFailure ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycardSuccess)
                        return true
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.migrateFromKeycardToApp) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migrateKeypairToApp ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToApp ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateFailure) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.migrateFromAppToKeycard) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migrateKeypairToKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pluginReader ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateFailure) {
                        return true
                    }
                }

                return false
            }

            sourceComponent: {
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }
                    if ((root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pluginReader && !d.hideKeyPair) ||
                            (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard && !d.hideKeyPair) ||
                            (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted && !d.hideKeyPair) ||
                            (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard && !d.hideKeyPair) ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateFailure) {
                        return keyPairForProcessingComponent
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }

                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhrase ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhraseSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhraseFailure) {
                        return keyPairForProcessingComponent
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }

                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhrase ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhraseSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhraseFailure ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.seedPhraseAlreadyInUse) {
                        return keyPairForProcessingComponent
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }

                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycardSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycardFailure ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.seedPhraseAlreadyInUse) {
                        return keyPairForProcessingComponent
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.factoryReset) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }
                    if(!!root.sharedKeycardModule.keyPairForProcessing &&
                            (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                             root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                             root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                             root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                             root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard))
                        return keyPairForProcessingComponent
                }
                if (d.authenticationOrSigning) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardEmpty ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.biometricsReadyToSign ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.biometricsPinFailed ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.biometricsPinInvalid ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard) {
                        return keyPairForProcessingComponent
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.displayKeycardContent) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.renameKeycard) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardRenameSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardRenameFailure) {
                        return keyPairForProcessingComponent
                    }
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard)
                        return keyPairForProcessingComponent
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPin) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard)
                        return keyPairForProcessingComponent
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPuk) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard)
                        return keyPairForProcessingComponent
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changePairingCode) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard)
                        return keyPairForProcessingComponent
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard) {
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.removeKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyToKeycard) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }
                    if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycardFailure ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycardSuccess)
                        return keyPairForProcessingComponent
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.migrateFromKeycardToApp) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migrateKeypairToApp ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToApp ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateFailure) {
                        return keyPairForProcessingComponent
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.migrateFromAppToKeycard) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migrateKeypairToKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pluginReader ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToKeycard ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateSuccess ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateFailure) {
                        return keyPairForProcessingComponent
                    }
                }

                return undefined
            }
        }
    }

    states: [
        State {
            name: Constants.keycardSharedState.pluginReader
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pluginReader
            PropertyChanges {
                target: title
                text: qsTr("Plug in Keycard reader...")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                source: Assets.png("keycard/wrong_card/something-went-wrong")
                pattern: ""
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.insertKeycard
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.insertKeycard
            PropertyChanges {
                target: title
                text: {
                    if (d.copyFromAKeycardPartDone) {
                        return qsTr("Tap or insert empty Keycard...")
                    }
                    return qsTr("Tap or insert Keycard...")
                }
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/card_insert/insert")
            }
            PropertyChanges {
                target: message
                text: root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.wronglyInsertedCard?
                          qsTr("Check the card, it might be wrongly inserted") :
                          ""
                color: Theme.palette.baseColor1
            }
        },
        State {
            name: Constants.keycardSharedState.keycardInserted
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardInserted
            PropertyChanges {
                target: title
                text: qsTr("Keycard inserted...")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/card_inserted/inserted")
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: d.processingStateName
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardFlowStarted ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToKeycard ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToApp ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhrase ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhrase ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycard ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.renamingKeycard ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.unlockingKeycard ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPin ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPuk ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPairingCode ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycard
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardFlowStarted) {
                        return qsTr("Starting...")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.readingKeycard) {
                        return qsTr("Reading Keycard...")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToKeycard) {
                        return qsTr("Migrating key pair to Keycard")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migratingKeypairToApp) {
                        return qsTr("Migrating key pair to Status")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhrase) {
                        return qsTr("Creating new account...")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhrase) {
                        return qsTr("Setting a new Keycard...")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycard) {
                        return qsTr("Importing from Keycard...")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.renamingKeycard) {
                        return qsTr("Renaming keycard...")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.unlockingKeycard) {
                        return qsTr("Unlocking keycard...")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPin) {
                        return qsTr("Updating PIN")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPuk) {
                        return qsTr("Setting your Keycard PUK...")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPairingCode) {
                        return qsTr("Setting your pairing code...")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycard) {
                        return qsTr("Copying Keycard...")
                    }
                    return ""
                }
                font.pixelSize: Theme.primaryTextFontSize
                color: Theme.palette.baseColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/scanning/scanning")
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.noPCSCService
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.noPCSCService
            PropertyChanges {
                target: title
                text: qsTr("PCSC not available")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/card_inserted/writing-negative")
            }
            PropertyChanges {
                target: message
                text: qsTr("The Smartcard reader (PCSC service), required\nfor using Keycard, is not currently working.\nEnsure PCSC is installed and running and try again")
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: Constants.keycardSharedState.notKeycard
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.notKeycard
            PropertyChanges {
                target: title
                text: qsTr("This is not a Keycard")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/wrong_card/not-keycard")
            }
            PropertyChanges {
                target: message
                text: qsTr("The card inserted is not a recognised Keycard,\nplease remove and try and again")
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: Constants.keycardSharedState.unlockKeycardOptions
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.unlockKeycardOptions
            PropertyChanges {
                target: title
                text: qsTr("Unlock this Keycard")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/pin/unblock")
            }
            PropertyChanges {
                target: message
                text: {
                    if (root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.disableSeedPhraseForUnlock &&
                            !(root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.offerPukForUnlock)) {
                        return qsTr("Please run \"Unlock Keycard\" flow directly")
                    }
                    return ""
                }
                color: Theme.palette.directColor1
            }
        },
        State {
            name: Constants.keycardSharedState.wrongKeycard
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeycard
            PropertyChanges {
                target: title
                text: qsTr("Wrong Keycard inserted")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: image
                source: Assets.png("keycard/wrong_card/wrong-profile")
                pattern: ""
            }
            PropertyChanges {
                target: message
                text: {
                    if (d.authenticationOrSigning ||
                            root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.renameKeycard ||
                            root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPin ||
                            root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPuk ||
                            root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changePairingCode ||
                            root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard ||
                            root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.factoryReset) {
                        return qsTr("Keycard inserted does not match the Keycard below")
                    }
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.migrateFromAppToKeycard) {
                        return qsTr("Keycard inserted does not match the Keycard below,\nplease remove and try and again")
                    }
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.unlockKeycard) {
                        return qsTr("Keycard inserted does not match the Keycard you're trying to unlock")
                    }
                    return ""
                }
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: Constants.keycardSharedState.keycardEmptyMetadata
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardEmptyMetadata
            PropertyChanges {
                target: title
                text: qsTr("This Keycard has empty metadata")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                source: Assets.png("keycard/card_inserted/inserted")
                pattern: ""
            }
            PropertyChanges {
                target: message
                text: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.migrateFromAppToKeycard) {
                        return qsTr("This Keycard already stores keys\nbut doesn't store any metadata,\nplease remove and try and again")
                    }

                    return qsTr("This Keycard already stores keys\nbut doesn't store any metadata")
                }
                color: Theme.palette.directColor1
            }
        },
        State {
            name: Constants.keycardSharedState.keycardEmpty
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardEmpty
            PropertyChanges {
                target: title
                text: qsTr("Keycard is empty")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                source: Assets.png("keycard/wrong_card/wrong-profile")
                pattern: ""
            }
            PropertyChanges {
                target: message
                text: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.migrateFromAppToKeycard) {
                        return qsTr("There is no key pair on this Keycard,\nplease remove and try and again")
                    }

                    return qsTr("There is no key pair on this Keycard")
                }
                color: Theme.palette.directColor1
            }
        },
        State {
            name: Constants.keycardSharedState.keycardNotEmpty
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardNotEmpty
            PropertyChanges {
                target: title
                text: qsTr("This Keycard already stores keys")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                source: Assets.png("keycard/card_inserted/inserted")
                pattern: ""
            }
            PropertyChanges {
                target: message
                text: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard) {
                        return qsTr("To migrate %1 on to this Keycard, you\nwill need to perform a factory reset first")
                        .arg(root.sharedKeycardModule.keyPairForProcessing.name)
                    }
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase ||
                            root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase) {
                        return qsTr("To create a new account on to this Keycard, you\nwill need to perform a factory reset first")
                    }
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard) {
                        return qsTr("To copy %1 on to this Keycard, you\nwill need to perform a factory reset first")
                        .arg(root.sharedKeycardModule.keyPairForProcessing.name)
                    }

                    return ""
                }
                color: Theme.palette.directColor1
            }
        },
        State {
            name: "sharedLockedState"
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached
            PropertyChanges {
                target: title
                text: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard ||
                      root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase ||
                      root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase ||
                      root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard?
                          qsTr("Keycard locked and already stores keys") : qsTr("Keycard locked")
                color: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard ||
                       root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase ||
                       root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase ||
                       root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard?
                           Theme.palette.directColor1 : Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/card_inserted/writing-negative")
            }
            PropertyChanges {
                target: message
                text: {
                    if (root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.useGeneralMessageForLockedState) {
                        if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard ||
                                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase ||
                                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase ||
                                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard)
                            return qsTr("The Keycard you have inserted is locked,\nyou will need to factory reset it before proceeding")
                        return qsTr("You will need to unlock it before proceeding")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPinRetriesReached)
                        return qsTr("Pin entered incorrectly too many times")
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPukRetriesReached)
                        return qsTr("Puk entered incorrectly too many times")
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.maxPairingSlotsReached)
                        return qsTr("Max pairing slots reached for the entered keycard")
                    return ""
                }
                color: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard ||
                       root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase ||
                       root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase ||
                       root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard?
                           Theme.palette.directColor1 : Theme.palette.dangerColor1
            }
        },
        State {
            name: Constants.keycardSharedState.keycardAlreadyUnlocked
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardAlreadyUnlocked
            PropertyChanges {
                target: title
                text: qsTr("Your Keycard is already unlocked!")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/card_inserted/writing-positive")
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.recognizedKeycard
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.recognizedKeycard
            PropertyChanges {
                target: title
                text: qsTr("Keycard recognized")
                font.pixelSize: Theme.primaryTextFontSize
                font.weight: Font.Normal
                color: Theme.palette.baseColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/profile/positive")
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: d.processingSuccessStateName
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateSuccess ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhraseSuccess ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhraseSuccess ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycardSuccess ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetSuccess ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.unlockKeycardSuccess ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardRenameSuccess ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPukSuccess ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPairingCodeSuccess ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycardSuccess
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateSuccess) {
                        return qsTr("Key pair successfully migrated")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhraseSuccess) {
                        return qsTr("New account successfully created")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhraseSuccess) {
                        return qsTr("Keycard is ready to use!")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycardSuccess) {
                        return qsTr("Account successfully imported")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetSuccess) {
                        if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard ||
                                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase ||
                                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase ||
                                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard)
                            return qsTr("Your Keycard has been reset")
                        return qsTr("Keycard successfully factory reset")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.unlockKeycardSuccess) {
                        return qsTr("Unlock successful")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardRenameSuccess) {
                        return qsTr("Keycard successfully renamed")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPukSuccess) {
                        return qsTr("Keycard’s PUK successfully set")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPairingCodeSuccess) {
                        return qsTr("Pairing code successfully set")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycardSuccess) {
                        return qsTr("This Keycard is now a copy of %1")
                        .arg(root.sharedKeycardModule.keyPairForProcessing.name)
                    }
                    return ""
                }
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetSuccess) {
                        return Assets.png("keycard/factory_reset/keycard-factory-reset-positive")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateSuccess) {
                        return Assets.png("keycard/profile/positive")
                    }
                    return Assets.png("keycard/card_inserted/writing-positive")
                }
            }
            PropertyChanges {
                target: message
                text: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateSuccess) {
                        if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.migrateFromKeycardToApp) {
                            return qsTr("Key pair was removed from Keycard and is now stored on device.\nYou no longer need this Keycard to transact with the below accounts.")
                        }
                        if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.migrateFromAppToKeycard) {
                            return qsTr("To complete migration close Status and sign in with your Keycard")
                        }
                        return qsTr("To complete migration close Status and log in with your new Keycard")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetSuccess) {
                        if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard ||
                                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase ||
                                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase ||
                                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard)
                            return qsTr("You can now create a new key pair on this Keycard")
                        return qsTr("You can now use this Keycard as if it\nwas a brand new empty Keycard")
                    }
                    return ""
                }
                color: Theme.palette.directColor1
            }
        },
        State {
            name: d.processingFailureStateName
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateFailure ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhraseFailure ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhraseFailure ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycardFailure ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardRenameFailure ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.unlockKeycardFailure ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPukFailure ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPairingCodeFailure ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycardFailure
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateFailure) {
                        return qsTr("Failed to migrate key pair")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhraseFailure) {
                        return qsTr("Creating new account failed")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountOldSeedPhraseFailure) {
                        return qsTr("Setting a Keycard failed")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.importingFromKeycardFailure) {
                        return qsTr("Importing account failed")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardRenameFailure) {
                        return qsTr("Keycard renaming failed")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.unlockKeycardFailure) {
                        return qsTr("Unlock a Keycard failed")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPukFailure) {
                        return qsTr("Setting Keycard’s PUK failed")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPairingCodeFailure) {
                        return qsTr("Setting pairing code failed")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyingKeycardFailure) {
                        return qsTr("Copying %1 Keycard failed")
                        .arg(root.sharedKeycardModule.keyPairForProcessing.name)
                    }
                    return ""
                }
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keyPairMigrateFailure ||
                    root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.creatingAccountNewSeedPhraseFailure) {
                        return Assets.png("keycard/profile/negative")
                    }
                    return Assets.png("keycard/card_inserted/writing-negative")
                }
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.keycardMetadataDisplay
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.keycardMetadataDisplay
            PropertyChanges {
                target: title
                text: qsTr("Accounts on this Keycard")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                source: Assets.png("keycard/card_inserted/inserted")
                pattern: ""
            }
            PropertyChanges {
                target: message
                text: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard &&
                        root.sharedKeycardModule.keyPairHelper.accounts.count > root.sharedKeycardModule.remainingAccountCapacity()?
                          qsTr("Adding these accounts will exceed the limit of 20.\nRemove some already added accounts to be able to import a new ones.")
                        : ""
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: Constants.keycardSharedState.biometricsReadyToSign
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.biometricsReadyToSign
            PropertyChanges {
                target: title
                text: qsTr("Ready to authenticate...")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                source: Assets.png("keycard/card_inserted/inserted")
                pattern: ""
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.biometricsPasswordFailed
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.biometricsPasswordFailed
            PropertyChanges {
                target: image
                source: Assets.png("keycard/biometrics-fail")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Biometric scan failed")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: message
                text: qsTr("Biometrics incorrect")
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: Constants.keycardSharedState.biometricsPinFailed
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.biometricsPinFailed
            PropertyChanges {
                target: image
                source: Assets.png("keycard/card_inserted/writing-negative")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Biometric scan failed")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: message
                text: qsTr("Biometrics incorrect")
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: Constants.keycardSharedState.biometricsPinInvalid
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.biometricsPinInvalid
            PropertyChanges {
                target: image
                source: Assets.png("keycard/pin/negative")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Biometric pin invalid")
                color: Theme.palette.dangerColor1
            }
            PropertyChanges {
                target: message
                text: qsTr("The PIN length doesn't match Keycard's PIN length")
                color: Theme.palette.baseColor1
            }
        },
        State {
            name: Constants.keycardSharedState.removeKeycard
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.removeKeycard
            PropertyChanges {
                target: title
                text: qsTr("Remove Keycard")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/wrong_card/something-went-wrong")
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.sameKeycard
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.sameKeycard
            PropertyChanges {
                target: title
                text: qsTr("Oops this is the same Keycard!")
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/profile/already-added")
            }
            PropertyChanges {
                target: message
                text: qsTr("You need to remove this Keycard and insert\nan empty new or factory reset Keycard")
                color: Theme.palette.directColor1
            }
        },
        State {
            name: Constants.keycardSharedState.copyToKeycard
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.copyToKeycard
            PropertyChanges {
                target: title
                text: qsTr("Copy “%1” to inserted keycard")
                .arg(root.sharedKeycardModule.keyPairForProcessing.name)
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                source: Assets.png("keycard/profile/in-progress")
                pattern: ""
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.seedPhraseAlreadyInUse
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.seedPhraseAlreadyInUse
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase) {
                        return qsTr("This recovery phrase has already been imported")
                    }
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.importFromKeycard) {
                        return qsTr("This keycard has already been imported")
                    }
                    return ""
                }
                color: Theme.palette.directColor1
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/card_inserted/writing-positive")
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.migrateKeypairToApp
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migrateKeypairToApp
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migrateKeypairToApp) {
                        if (root.sharedKeycardModule.keyPairForProcessing.pairType === Constants.keycard.keyPairType.profile) {
                            if (root.sharedKeycardModule.forceFlow) {
                                return qsTr("Your profile key pair has been\nmigrated from Keycard to Status")
                            }
                        }
                        return qsTr("Are you sure you want to migrate\nthis key pair to Status?")
                    }
                    return ""
                }
                color: Theme.palette.directColor1
                horizontalAlignment: Text.AlignHCenter
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: ""
            }
            PropertyChanges {
                target: message
                text: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migrateKeypairToApp) {
                        if (root.sharedKeycardModule.keyPairForProcessing.pairType === Constants.keycard.keyPairType.profile) {
                            if (root.sharedKeycardModule.forceFlow) {
                                return qsTr("In order to continue using this profile on this device, you need to enter the key pairs recovery phrase and create a new password to log in with on this device.")
                            }

                            let t = qsTr("%1 is your default Status key pair.").arg(root.sharedKeycardModule.keyPairForProcessing.name)
                            t += qsTr(" Migrating this key pair will mean you will no longer require this Keycard to login to Status or transact with the key pair’s derived accounts.")
                            t += qsTr(" The key pair and accounts will be fully removed from Keycard and stored on device.")
                            return t
                        }

                        let t = qsTr("%1 key pair and its derived accounts will be fully removed from Keycard and stored on device.").arg(root.sharedKeycardModule.keyPairForProcessing.name)
                        t += qsTr(" This will make your key pair and derived accounts less secure as you will no longer require this Keycard to transact.")
                        return t
                    }
                    return ""
                }
                color: Theme.palette.directColor1
                Layout.leftMargin: 2 * Theme.xlPadding
                Layout.rightMargin: 2* Theme.xlPadding
                Layout.preferredWidth: layout.width - 4 * Theme.xlPadding
            }
        },
        State {
            name: Constants.keycardSharedState.migrateKeypairToKeycard
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migrateKeypairToKeycard
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migrateKeypairToKeycard) {
                        if (root.sharedKeycardModule.keyPairForProcessing.pairType === Constants.keycard.keyPairType.profile) {
                            if (root.sharedKeycardModule.forceFlow) {
                                return qsTr("Your profile key pair has been\nmigrated from Status to Keycard")
                            }
                        }
                    }
                    return ""
                }
                color: Theme.palette.directColor1
                horizontalAlignment: Text.AlignHCenter
            }
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/profile/positive")
            }
            PropertyChanges {
                target: message
                text: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.migrateKeypairToKeycard) {
                        if (root.sharedKeycardModule.keyPairForProcessing.pairType === Constants.keycard.keyPairType.profile) {
                            if (root.sharedKeycardModule.forceFlow) {
                                return qsTr("In order to continue using this profile on this device, you need to login using the Keycard that this profile key pair was migrated to.")
                            }
                        }
                    }
                    return ""
                }
                color: Theme.palette.directColor1
                Layout.leftMargin: 2 * Theme.xlPadding
                Layout.rightMargin: 2* Theme.xlPadding
                Layout.preferredWidth: layout.width - 4 * Theme.xlPadding
            }
        },
        State {
            name: Constants.keycardSharedState.biometrics
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.biometrics
            PropertyChanges {
                target: title
                text: qsTr("Biometrics")
                color: Theme.palette.directColor1
                horizontalAlignment: Text.AlignHCenter
            }
            PropertyChanges {
                target: image
                source: Assets.png("keycard/biometrics-success")
                pattern: ""
            }
            PropertyChanges {
                target: message
                text: qsTr("Would you like to use Touch ID\nto login to Status?")
                color: Theme.palette.baseColor1
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: layout.width - 4 * Theme.xlPadding
            }
        }
    ]
}
