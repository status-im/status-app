import QtQuick

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme

import AppLayouts.Onboarding.controls

import utils

KeycardBasePage {
    id: root

    enum State {
        Idle,
        InProgress,
        Success,
        WrongPin
    }

    required property int state

    required property int remainingAttempts
    required property bool unblockWithPukAvailable

    signal authorizationRequested(string pin)
    signal unblockWithSeedphraseRequested
    signal unblockWithPukRequested
    signal keycardFactoryResetRequested

    StateGroup {
        id: states
        states: [
            State { // entering
                when: root.state === KeycardEnterPinPage.State.Idle &&
                      root.remainingAttempts > 0

                PropertyChanges {
                    target: root
                    title: qsTr("Enter Keycard PIN")
                }
                StateChangeScript {
                    script: {
                        pinInput.statesInitialization()
                    }
                }

                PropertyChanges {
                    target: image
                    source: Assets.png("keycard/pin/in-progress")
                }
            },
            State { // entering, wrong pin
                when: root.state === KeycardEnterPinPage.State.WrongPin
                      && root.remainingAttempts > 0

                PropertyChanges {
                    target: root
                    title: qsTr("PIN incorrect")
                }
                PropertyChanges {
                    target: errorText
                    visible: true
                }
                StateChangeScript {
                    script: {
                        Backpressure.debounce(root, 100, function() {
                            pinInput.clearPin()
                        })()
                    }
                }
                PropertyChanges {
                    target: image
                    source: Assets.png("keycard/pin/negative")
                }
            },
            State { // in progress
                when: root.state === KeycardEnterPinPage.State.InProgress &&
                      root.remainingAttempts > 0

                PropertyChanges {
                    target: root
                    title: qsTr("Authorizing")
                }
                PropertyChanges {
                    target: pinInput
                    enabled: false
                }
                PropertyChanges {
                    target: loadingIndicator
                    visible: true
                }

                PropertyChanges {
                    target: image
                    source: Assets.png("keycard/pin/in-progress")
                }
            },
            State { // success
                when: root.state === KeycardEnterPinPage.State.Success
                      && root.remainingAttempts > 0

                PropertyChanges {
                    target: root
                    title: qsTr("PIN correct")
                }
                PropertyChanges {
                    target: pinInput
                    enabled: false
                }

                PropertyChanges {
                    target: image
                    source: Assets.png("keycard/pin/positive")
                }
            },
            State { // blocked
                when: root.remainingAttempts <= 0

                PropertyChanges {
                    target: root

                    title: `<font color='${Theme.palette.dangerColor1}'>`
                           + `${qsTr("Keycard blocked")}</font>`
                }
                PropertyChanges {
                    target: pinInput
                    enabled: false
                }
                PropertyChanges {
                    target: image
                    source: Assets.png("keycard/pin/negative")
                }
                PropertyChanges {
                    target: btnUnblockWithSeedphrase
                    visible: true
                }
                PropertyChanges {
                    target: btnUnblockWithPuk
                    visible: root.unblockWithPukAvailable
                }
                StateChangeScript {
                    script: {
                        Backpressure.debounce(root, 100, function() {
                            pinInput.clearPin()
                        })()
                    }
                }
            }
        ]
    }

    buttons: [
        StatusPinInput {
            id: pinInput

            anchors.horizontalCenter: parent.horizontalCenter
            pinLen: Constants.keycard.general.keycardPinLength
            validator: StatusIntValidator { bottom: 0; top: 999999 }
            inputMethodHints: Qt.ImhDigitsOnly
            onPinInputChanged: {
                if (pinInput.pinInput.length === pinInput.pinLen) {
                    root.authorizationRequested(pinInput.pinInput)
                }
            }
        },
        StatusBaseText {
            id: errorText

            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("%n attempt(s) remaining", "", root.remainingAttempts)
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.dangerColor1
            visible: false
        },
        StatusLoadingIndicator {
            id: loadingIndicator

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Theme.halfPadding
            visible: false
        },
        MaybeOutlineButton {
            id: btnUnblockWithPuk

            visible: false
            isOutline: false
            text: qsTr("Unblock using PUK")
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: root.unblockWithPukRequested()

            /////////////////////////////////////////////////////////////////////////////////
            // # Remove this once we implement unlock via PUK
            /////////////////////////////////////////////////////////////////////////////////
            enabled: false
            MouseArea {
                id: unlockWithPukArea
                anchors.fill: parent
                hoverEnabled: true
            }
            StatusToolTip {
                text: Constants.keycard.temporarilyUnavailable
                visible: unlockWithPukArea.containsMouse
            }
            /////////////////////////////////////////////////////////////////////////////////
        },
        MaybeOutlineButton {
            id: btnUnblockWithSeedphrase

            visible: false
            isOutline: btnUnblockWithPuk.visible
            text: qsTr("Unblock with recovery phrase")
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: root.unblockWithSeedphraseRequested()

            /////////////////////////////////////////////////////////////////////////////////
            // # Remove this once we implement unlock via PUK
            /////////////////////////////////////////////////////////////////////////////////
            enabled: false
            MouseArea {
                id: unlockWithSeedphraseArea
                anchors.fill: parent
                hoverEnabled: true
            }
            StatusToolTip {
                text: Constants.keycard.temporarilyUnavailable
                visible: unlockWithSeedphraseArea.containsMouse
            }
            /////////////////////////////////////////////////////////////////////////////////
        }
    ]
}
