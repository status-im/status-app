import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

import shared
import utils

import shared.panels as SharedPanels

Control {
    id: root

    property var sharedKeycardModule

    signal validation(bool result)

    QtObject {
        id: d

        property bool wrongSeedPhrase: root.sharedKeycardModule.keycardData & Constants.predefinedKeycardData.wrongSeedPhrase
        onWrongSeedPhraseChanged: {
            seedPhrase.setError(wrongSeedPhrase? qsTr("The phrase you’ve entered does not match this Keycard’s recovery phrase") : "")
        }

    }

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.xlPadding

        TitleText {
            id: title

            Layout.fillWidth: true

            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        SharedPanels.EnterSeedPhrase {
            id: seedPhrase

            Layout.fillWidth: true

            dictionary: BIP39_en {}
            flickable: scrollView.flickable

            onSeedPhraseProvided: seedPhrase => {
                const phrase = seedPhrase.join(" ")
                const valid = root.sharedKeycardModule.validSeedPhrase(phrase)

                if (valid) {
                    setError("")
                    root.sharedKeycardModule.setSeedPhrase(phrase)
                } else {
                    setError(qsTr("Invalid recovery phrase"))
                }

                root.validation(valid)
            }

            onSeedPhraseAccepted: {
                root.sharedKeycardModule.currentState.doPrimaryAction()
            }
        }
    }

    states: [
        State {
            name: Constants.keycardSharedState.enterSeedPhrase
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.enterSeedPhrase
            PropertyChanges {
                target: title
                text: {
                    switch (root.sharedKeycardModule.currentState.flowType) {
                    case Constants.keycardSharedFlow.migrateFromKeycardToApp:
                        return qsTr("Enter recovery phrase for %1 key pair").arg(root.sharedKeycardModule.keyPairForProcessing.name)
                    }

                    return ""
                }
            }
        },
        State {
            name: Constants.keycardSharedState.wrongSeedPhrase
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongSeedPhrase
            PropertyChanges {
                target: title
                text: {
                    switch (root.sharedKeycardModule.currentState.flowType) {
                    case Constants.keycardSharedFlow.migrateFromKeycardToApp:
                        return qsTr("Enter recovery phrase for %1 key pair").arg(root.sharedKeycardModule.keyPairForProcessing.name)
                    }

                    return ""
                }
            }
        }
    ]
}
