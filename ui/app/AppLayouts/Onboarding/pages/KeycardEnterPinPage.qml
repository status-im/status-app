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
                        pinInput.forceFocus()
                    }
                }

                PropertyChanges {
                    target: image
                    source: Assets.png("onboarding/keycard/reading")
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
                    source: Assets.png("onboarding/keycard/error")
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
                    source: Assets.png("onboarding/keycard/reading")
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
                    source: Assets.png("onboarding/keycard/success")
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
                    source: Assets.png("onboarding/keycard/error")
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
        },
        MaybeOutlineButton {
            id: btnUnblockWithSeedphrase

            visible: false
            isOutline: btnUnblockWithPuk.visible
            text: qsTr("Unblock with recovery phrase")
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: root.unblockWithSeedphraseRequested()
        }
    ]
}
