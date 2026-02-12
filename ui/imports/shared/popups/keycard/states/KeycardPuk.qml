import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators

import utils

import "../helpers"

Control {
    id: root

    property var sharedKeycardModule

    property int remainingAttempts: root.sharedKeycardModule.remainingAttempts

    signal pukUpdated(string puk)

    onRemainingAttemptsChanged: {
        if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongPuk) {
            pukInputField.statesInitialization()
        }
    }

    onStateChanged: {
        pukInputField.statesInitialization()
    }
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        KeycardImage {
            id: image
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Constants.keycard.shared.imageHeight
            Layout.preferredWidth: Constants.keycard.shared.imageWidth
        }

        TitleText {
            id: title
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
        }

        StatusPinInput {
            id: pukInputField
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth
            Layout.alignment: Qt.AlignHCenter
            validator: StatusRegularExpressionValidator { regularExpression: /[0-9]+/ }
            pinLen: Constants.keycard.general.keycardPukLength
            additionalSpacing: Constants.keycard.general.keycardPukAdditionalSpacing
            additionalSpacingOnEveryNItems: Constants.keycard.general.keycardPukAdditionalSpacingOnEvery4Items

            onPinInputChanged: {
                root.pukUpdated(pinInput)
                if (root.sharedKeycardModule.currentState.stateType !== Constants.keycardSharedState.enterPuk &&
                        root.sharedKeycardModule.currentState.stateType !== Constants.keycardSharedState.wrongPuk) {
                    image.source = Assets.png("keycard/pin/in-progress")
                }
                if(pinInput.length == 0) {
                    return
                }
                if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.createPuk ||
                        root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.enterPuk ||
                        root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongPuk) {
                    root.sharedKeycardModule.setPuk(pinInput)
                    root.sharedKeycardModule.currentState.doSecondaryAction()
                }
                else if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.repeatPuk) {
                    let pukMatch = root.sharedKeycardModule.checkRepeatedKeycardPukWhileTyping(pinInput)
                    if (pukMatch) {
                        info.text = ""
                        root.sharedKeycardModule.currentState.doSecondaryAction()
                    } else {
                        info.text = qsTr("The PUK doesn’t match")
                        image.source = Assets.png("keycard/pin/negative")
                    }
                }
            }
        }

        StatusBaseText {
            id: info
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text !== ""

            color: Theme.palette.dangerColor1
            font.pixelSize: Theme.tertiaryTextFontSize
        }

        StatusBaseText {
            id: message
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text !== ""

            font.pixelSize: Theme.tertiaryTextFontSize
        }

        Item {
            id: spacer
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    states: [
        State {
            name: Constants.keycardSharedState.enterPuk
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.enterPuk
            PropertyChanges {
                target: image
                source: Assets.png("keycard/pin/in-progress")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Enter PUK")
            }
            PropertyChanges {
                target: info
                text: ""
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.wrongPuk
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongPuk
            PropertyChanges {
                target: image
                source: Assets.png("keycard/pin/negative")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Enter PUK")
            }
            PropertyChanges {
                target: info
                text: qsTr("The PUK is incorrect, try entering it again")
            }
            PropertyChanges {
                target: message
                text: qsTr("%n attempt(s) remaining", "", root.remainingAttempts)
                color: root.remainingAttempts === 1?
                           Theme.palette.dangerColor1 :
                           Theme.palette.baseColor1
            }
        },
        State {
            name: Constants.keycardSharedState.createPuk
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.createPuk
            PropertyChanges {
                target: image
                source: Assets.png("keycard/pin/in-progress")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Choose a Keycard PUK")
            }
            PropertyChanges {
                target: info
                text: ""
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.repeatPuk
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.repeatPuk
            PropertyChanges {
                target: image
                source: Assets.png("keycard/pin/in-progress")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Repeat your Keycard PUK")
            }
            PropertyChanges {
                target: info
                text: ""
            }
            PropertyChanges {
                target: message
                text: ""
            }
        }
    ]
}
