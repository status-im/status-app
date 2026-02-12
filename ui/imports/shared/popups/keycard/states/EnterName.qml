import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as StatusQUtils
import StatusQ.Controls

import utils

import "../helpers"

Control {
    id: root

    property var sharedKeycardModule

    signal validation(bool result)

    QtObject {
        id: d
        property bool entryValid: false

        function updateValidity() {
            d.entryValid = root.sharedKeycardModule.keyPairForProcessing.name.trim().length > 0
            if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.renameKeycard) {
                d.entryValid = d.entryValid && root.sharedKeycardModule.keyPairForProcessing.name !== root.sharedKeycardModule.getNameFromKeycard()
            }
            root.validation(d.entryValid)
        }
    }

    Component.onCompleted: {
        if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardNewSeedPhrase ||
                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycardOldSeedPhrase) {
            if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.enterKeycardName) {
                if (root.sharedKeycardModule.keyPairForProcessing.name.trim() !== "") {
                    d.updateValidity()
                    return
                }

                let color = Theme.palette.customisationColorsArray[Math.floor(Math.random() * Theme.palette.customisationColorsArray.length)]
                let emoji = StatusQUtils.Emoji.getRandomEmoji(StatusQUtils.Emoji.size.verySmall) // TODO: Reuse status-go RandomWalletEmoji
                root.sharedKeycardModule.keyPairForProcessing.observedAccount.name = "      "
                root.sharedKeycardModule.keyPairForProcessing.observedAccount.colorId = Utils.getIdForColor(Theme.palette, color)
                root.sharedKeycardModule.keyPairForProcessing.observedAccount.emoji = emoji
            }
        }

        d.updateValidity()
        keycardName.input.edit.forceActiveFocus()
    }

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        TitleText {
            id: title
            Layout.alignment: Qt.AlignCenter
        }

        StatusInput {
            id: keycardName
            Layout.preferredWidth: Constants.keycard.general.keycardNameInputWidth
            Layout.alignment: Qt.AlignCenter
            charLimit: Constants.keycard.general.keycardNameLength
            text: root.sharedKeycardModule.keyPairForProcessing.name
            input.acceptReturn: true

            onTextChanged: {
                root.sharedKeycardModule.keyPairForProcessing.name = text
                d.updateValidity()
            }

            onKeyPressed: {
                if (d.entryValid &&
                        (input.edit.keyEvent === Qt.Key_Return ||
                         input.edit.keyEvent === Qt.Key_Enter)) {
                    event.accepted = true
                    root.sharedKeycardModule.currentState.doPrimaryAction()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        StatusBaseText {
            Layout.alignment: Qt.AlignLeft
            text: qsTr("Preview")
            color: Theme.palette.baseColor1
        }

        KeyPairItem {
            Layout.preferredWidth: parent.width
            keyPairType: root.sharedKeycardModule.keyPairForProcessing.pairType
            keyPairKeyUid: root.sharedKeycardModule.keyPairForProcessing.keyUid
            keyPairName: root.sharedKeycardModule.keyPairForProcessing.name
            keyPairIcon: root.sharedKeycardModule.keyPairForProcessing.icon
            keyPairImage: root.sharedKeycardModule.keyPairForProcessing.image
            keyPairDerivedFrom: root.sharedKeycardModule.keyPairForProcessing.derivedFrom
            keyPairAccounts: root.sharedKeycardModule.keyPairForProcessing.accounts
            keyPairCardLocked: root.sharedKeycardModule.keyPairForProcessing.locked
        }
    }

    states: [
        State {
            name: Constants.keycardSharedState.enterKeycardName
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.enterKeycardName
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.renameKeycard) {
                        qsTr("Rename this Keycard")
                    }

                    return qsTr("Name this Keycard")
                }
            }
            PropertyChanges {
                target: keycardName
                placeholderText: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.renameKeycard) {
                        return qsTr("Keycard name")
                    }

                    return qsTr("What would you like this Keycard to be called?")
                }
            }
        }
    ]
}
