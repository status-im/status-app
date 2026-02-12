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

    signal pinUpdated(string pin)

    onRemainingAttemptsChanged: {
        if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongPin ||
                root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeychainPin) {
            pinInputField.statesInitialization()
        }
    }

    onStateChanged: {
        if(d.useFakePin) {
            pinInputField.setPin("123456") // we are free to set fake pin in this case
        } else {
            pinInputField.statesInitialization()
        }
    }

    Component.onCompleted: {
        if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.authentication ||
                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.sign ||
                root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.factoryReset) {
            timer.start()
        }
    }

    Timer {
        id: timer
        interval: 500
        onTriggered: {
            pinInputField.statesInitialization()
        }
    }

    QtObject {
        id: d
        readonly property bool useFakePin: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pinSet ||
                                           root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pinVerified ||
                                           root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPinSuccess ||
                                           root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPinFailure
        readonly property string message1: qsTr("It is very important that you do not lose this PIN")
        readonly property string message2: qsTr("Don’t lose your PIN! If you do, you may lose\naccess to your funds.")
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
        }
    }

    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    contentItem: ColumnLayout {
        spacing: root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.authentication ||
                 root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.sign?
                     Theme.halfPadding : Theme.padding

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
            wrapMode: Text.WordWrap
        }

        StatusBaseText {
            id: subTitle
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text !== ""

            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.baseColor1
        }

        StatusPinInput {
            id: pinInputField
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth
            Layout.alignment: Qt.AlignHCenter
            validator: StatusIntValidator{bottom: 0; top: 999999;}
            pinLen: Constants.keycard.general.keycardPinLength
            enabled: !d.useFakePin
            onPinInputChanged: {
                root.pinUpdated(pinInput)
                if (root.sharedKeycardModule.currentState.stateType !== Constants.keycardSharedState.wrongPin &&
                        root.sharedKeycardModule.currentState.stateType !== Constants.keycardSharedState.wrongKeychainPin) {
                    image.source = Assets.png("keycard/pin/in-progress")
                }
                if(pinInput.length === 0) {
                    return
                }
                if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.createPin ||
                        root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.enterPin ||
                        root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongPin ||
                        root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeychainPin) {
                    root.sharedKeycardModule.setPin(pinInput)
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.authentication ||
                            root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.sign)
                        return
                    root.sharedKeycardModule.currentState.doSecondaryAction()
                }
                else if(root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.repeatPin) {
                    let pinsMatch = root.sharedKeycardModule.checkRepeatedKeycardPinWhileTyping(pinInput)
                    if (pinsMatch) {
                        if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPin)
                            info.text = d.message2
                        else
                            info.text = d.message1
                        root.sharedKeycardModule.currentState.doSecondaryAction()
                    } else {
                        info.text = qsTr("PINs don't match")
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

            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.dangerColor1
        }

        StatusBaseText {
            id: message
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: text !== ""

            font.pixelSize: Theme.tertiaryTextFontSize
        }

        Loader {
            id: loader
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth
            Layout.alignment: Qt.AlignHCenter
            active: {
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.createPin ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.repeatPin ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pinSet) {
                        return true
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.authentication ||
                        root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.sign) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.enterPin ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongPin ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeychainPin) {
                        return true
                    }
                }

                return false
            }

            sourceComponent: {
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.setupNewKeycard) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.createPin ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.repeatPin ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pinSet) {
                        return keyPairForProcessingComponent
                    }
                }
                if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.authentication ||
                        root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.sign) {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.enterPin ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongPin ||
                            root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeychainPin) {
                        return keyPairForProcessingComponent
                    }
                }

                return undefined
            }
        }

        Item {
            id: spacer
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !loader.active
        }
    }

    states: [
        State {
            name: Constants.keycardSharedState.enterPin
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.enterPin
            PropertyChanges {
                target: image
                source: Assets.png("keycard/pin/in-progress")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPin) {
                        return qsTr("Enter the Keycard PIN")
                    }
                    return qsTr("Enter this Keycard’s PIN")
                }
            }
            PropertyChanges {
                target: subTitle
                text: ""
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
            name: Constants.keycardSharedState.wrongPin
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongPin
            PropertyChanges {
                target: image
                source: Assets.png("keycard/pin/negative")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Enter Keycard PIN")
            }
            PropertyChanges {
                target: subTitle
                text: ""
            }
            PropertyChanges {
                target: info
                text: qsTr("PIN incorrect")
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
            name: Constants.keycardSharedState.wrongKeychainPin
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongKeychainPin
            PropertyChanges {
                target: image
                source: Assets.png("keycard/pin/negative")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Your saved PIN is out of date")
            }
            PropertyChanges {
                target: subTitle
                text: qsTr("Enter your new PIN to proceed")
            }
            PropertyChanges {
                target: info
                text: qsTr("PIN incorrect")
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
            name: Constants.keycardSharedState.createPin
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.createPin
            PropertyChanges {
                target: image
                source: Assets.png("keycard/pin/in-progress")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPin) {
                        return qsTr("Enter new Keycard PIN")
                    }
                    return qsTr("Choose a Keycard PIN")
                }
            }
            PropertyChanges {
                target: subTitle
                text: ""
            }
            PropertyChanges {
                target: info
                text: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPin) {
                        return d.message2
                    }
                    return d.message1
                }
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.repeatPin
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.repeatPin
            PropertyChanges {
                target: image
                source: Assets.png("keycard/pin/in-progress")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPin) {
                        return qsTr("Repeat new Keycard PIN")
                    }
                    return qsTr("Repeat Keycard PIN")
                }
            }
            PropertyChanges {
                target: subTitle
                text: ""
            }
            PropertyChanges {
                target: info
                text: {
                    if (root.sharedKeycardModule.currentState.flowType === Constants.keycardSharedFlow.changeKeycardPin) {
                        return d.message2
                    }
                    return d.message1
                }
            }
            PropertyChanges {
                target: message
                text: ""
            }
        },
        State {
            name: "success-state"
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pinSet ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pinVerified ||
                  root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPinSuccess
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/pin/positive")
            }
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pinSet) {
                        return qsTr("Keycard PIN set")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.pinVerified) {
                        return qsTr("Keycard PIN verified!")
                    }
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPinSuccess) {
                        return qsTr("PIN successfully changed")
                    }
                    return ""
                }
            }
            PropertyChanges {
                target: subTitle
                text: ""
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
            name: "error-state"
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPinFailure
            PropertyChanges {
                target: image
                pattern: ""
                source: Assets.png("keycard/pin/negative")
            }
            PropertyChanges {
                target: title
                text: {
                    if (root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.changingKeycardPinFailure) {
                        return qsTr("Changing PIN failed")
                    }
                    return ""
                }
            }
            PropertyChanges {
                target: subTitle
                text: ""
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
