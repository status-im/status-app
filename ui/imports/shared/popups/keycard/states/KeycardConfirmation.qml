import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

import "../helpers"

Control {
    id: root

    property string myKeyUid

    property var sharedKeycardModule

    signal confirmationUpdated(bool value)

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
        }
    }

    Component {
        id: unknownKeyPairCompontnt
        KeyPairUnknownItem {
            keyPairKeyUid: root.sharedKeycardModule.keyPairForProcessing.keyUid
            keyPairName: root.sharedKeycardModule.keyPairForProcessing.name
            keyPairIcon: root.sharedKeycardModule.keyPairForProcessing.icon
            keyPairImage: root.sharedKeycardModule.keyPairForProcessing.image
            keyPairDerivedFrom: root.sharedKeycardModule.keyPairForProcessing.derivedFrom
            keyPairAccounts: root.sharedKeycardModule.keyPairForProcessing.accounts
            keyPairCardLocked: root.sharedKeycardModule.keyPairForProcessing.locked
        }
    }


    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        KeycardImage {
            id: image
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Constants.keycard.shared.imageHeight
            Layout.preferredWidth: Constants.keycard.shared.imageWidth
            pattern: ""
            source: Assets.png("keycard/factory_reset/keycard-factory-reset")
        }

        StatusBaseText {
            id: title
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: {
                if (!!root.sharedKeycardModule.keyPairForProcessing &&
                        root.sharedKeycardModule.keyPairForProcessing.keyUid === root.myKeyUid)
                    return qsTr("Warning, this Keycard stores your main Status profile and\naccounts. A factory reset will permanently delete it.")

                return qsTr("A factory reset will delete the key on this Keycard.\nAre you sure you want to do this?")
            }
            color: Theme.palette.dangerColor1
            wrapMode: Text.WordWrap
        }

        StatusCheckBox {
            id: confirmation
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: parent.width
            leftSide: false
            spacing: Theme.smallPadding
            text: qsTr("I understand the key pair on this Keycard will be deleted")

            onCheckedChanged: {
                root.confirmationUpdated(checked)
            }
        }

        Loader {
            id: loader
            Layout.preferredWidth: parent.width
            active: {
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.factoryReset) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata) {
                        return true
                    }
                }
                return false
            }

            sourceComponent: {
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.factoryReset) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.createCopyOfAKeycard) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.factoryResetConfirmationDisplayMetadata) {
                        if (root.sharedKeycardModule.keyPairStoredOnKeycardIsKnown) {
                            return keyPairForProcessingComponent
                        }
                        return unknownKeyPairCompontnt
                    }
                }
            }
        }

        Item {
            visible: !loader.active
            Layout.fillWidth: true
            Layout.fillHeight: visible
        }
    }
}
