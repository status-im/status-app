import QtQuick

import StatusQ.Core
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Core.Theme

import AppLayouts.Onboarding.controls

KeycardBasePage {
    id: root

    property bool success

    readonly property bool pinSettingInProgress: d.state === "settingInProgress"

    signal setPinRequested(string pin)

    image.source: Assets.png("keycard/pin/in-progress")

    buttons: [
        StatusPinInput {
            id: pinInput

            anchors.horizontalCenter: parent.horizontalCenter

            validator: StatusIntValidator { bottom: 0; top: 999999 }

            onPinInputChanged: Qt.callLater(d.setPins)

            Component.onCompleted: {
                statesInitialization()
            }
        },

        StatusBaseText {
            id: errorText

            anchors.horizontalCenter: parent.horizontalCenter
            visible: false

            text: qsTr("PINs don't match")
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.dangerColor1
        },

        StatusLoadingIndicator {
            id: loadingIndicator

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Theme.halfPadding
            visible: false
        }
    ]

    StateGroup {
        id: d

        state: "creating"

        property string pin
        property string pin2

        readonly property bool matchingPinsProvided: pin && pin2 && pin === pin2

        function setPins() {
            if (!pinInput.valid)
                return

            if (d.state === "creating")
                d.pin = pinInput.pinInput
            else if (d.state === "repeating" || d.state === "mismatch")
                d.pin2 = pinInput.pinInput

            if (d.state === "mismatch")
                pinInput.statesInitialization()
        }

        states: [
            State {
                name: "creating"

                PropertyChanges {
                    target: root
                    title: qsTr("Create new Keycard PIN")
                }
            },
            State {
                name: "repeating"
                when: d.pin !== "" && d.pin2 === ""

                PropertyChanges {
                    target: root
                    title: qsTr("Repeat Keycard PIN")
                }
                StateChangeScript {
                    script: {
                        pinInput.statesInitialization()
                    }
                }
            },
            State {
                name: "mismatch"
                extend: "repeating"
                when: !!d.pin && !!d.pin2 && d.pin !== d.pin2

                PropertyChanges {
                    target: errorText
                    visible: true
                }
                PropertyChanges {
                    target: root
                    image.source: Assets.png("keycard/pin/negative")
                }
            },
            State {
                name: "settingInProgress"
                extend: "repeating"
                when: d.matchingPinsProvided && !root.success

                PropertyChanges {
                    target: root
                    title: qsTr("Setting Keycard PIN")
                }
                PropertyChanges {
                    target: pinInput
                    enabled: false
                }
                PropertyChanges {
                    target: loadingIndicator
                    visible: true
                }
                StateChangeScript {
                    script: {
                        pinInput.setPin(d.pin)
                        root.setPinRequested(d.pin)
                    }
                }
            },
            State {
                name: "success"
                when: d.matchingPinsProvided && root.success

                PropertyChanges {
                    target: root
                    title: qsTr("PIN set")
                }
                PropertyChanges {
                    target: pinInput
                    enabled: false
                }
                PropertyChanges {
                    target: root
                    image.source: Assets.png("keycard/pin/positive")
                }
            }
        ]
    }
}
