import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators

import utils

import "../helpers"

Control {
    id: root

    property var sharedKeycardModule

    property string kcData: root.sharedKeycardModule.keycardData

    signal passwordValid(bool valid)

    onKcDataChanged: {
        d.updatePasswordValidation()
    }

    onStateChanged: {
        password.focus = !SQUtils.Utils.isMobile
    }

    Component.onCompleted: timer.start()

    Timer {
        id: timer
        interval: 1000
        onTriggered: {
            password.forceActiveFocus(Qt.MouseFocusReason)
        }
    }

    QtObject {
        id: d

        readonly property bool wrongPassword: root.kcData & Constants.predefinedKeycardData.wrongPassword

        function updatePasswordValidation() {
            root.passwordValid(password.text !== "" && !d.wrongPassword)
        }
    }

    topPadding: Theme.halfPadding
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
        }

        TitleText {
            id: title
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: parent.width
        }

        StatusBaseText {
            id: message
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: parent.width
            wrapMode: Text.WordWrap
            visible: text != ""
        }

        StatusPasswordInput {
            id: password
            objectName: "keycardPasswordInput"
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            placeholderText: qsTr("Password")
            selectByMouse: true
            focus: !SQUtils.Utils.isMobile

            onTextChanged: {
                root.sharedKeycardModule.keycardData = ""
                root.sharedKeycardModule.setPassword(text)
                d.updatePasswordValidation()
            }

            onAccepted: {
                if (password.text !== "") {
                    root.sharedKeycardModule.currentState.doPrimaryAction()
                }
            }
        }

        StatusBaseText {
            id: info
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: parent.width
            wrapMode: Text.WordWrap
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    states: [
        State {
            name: Constants.keycardSharedState.enterPassword
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.enterPassword
            PropertyChanges {
                target: image
                source: Assets.png("keycard/authenticate")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Enter your password")
            }
            PropertyChanges {
                target: message
                text: ""
            }
            PropertyChanges {
                target: info
                text: ""
            }
        },
        State {
            name: Constants.keycardSharedState.wrongPassword
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongPassword
            PropertyChanges {
                target: image
                source: Assets.png("keycard/authenticate")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Enter your password")
            }
            PropertyChanges {
                target: message
                text: ""
            }
            PropertyChanges {
                target: info
                text: d.wrongPassword? qsTr("Password incorrect") : ""
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: Constants.keycardSharedState.enterBiometricsPassword
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.enterBiometricsPassword
            PropertyChanges {
                target: image
                source: Assets.png("keycard/biometrics-success")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Stored password doesn't match")
            }
            PropertyChanges {
                target: message
                text: qsTr("Enter your new password to proceed")
                color: Theme.palette.baseColor1
            }
            PropertyChanges {
                target: info
                text: d.wrongPassword? qsTr("Password incorrect") : ""
                color: Theme.palette.dangerColor1
            }
        },
        State {
            name: Constants.keycardSharedState.wrongBiometricsPassword
            when: root.sharedKeycardModule.currentState.stateType === Constants.keycardSharedState.wrongBiometricsPassword
            PropertyChanges {
                target: image
                source: Assets.png("keycard/biometrics-success")
                pattern: ""
            }
            PropertyChanges {
                target: title
                text: qsTr("Stored password doesn't match")
            }
            PropertyChanges {
                target: message
                text: qsTr("Enter your new password to proceed")
                color: Theme.palette.baseColor1
            }
            PropertyChanges {
                target: info
                text: d.wrongPassword? qsTr("Password incorrect") : ""
                color: Theme.palette.dangerColor1
            }
        }
    ]
}
