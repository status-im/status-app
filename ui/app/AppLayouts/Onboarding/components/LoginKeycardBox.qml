import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Onboarding.enums
import AppLayouts.Onboarding.controls

import utils

Control {
    id: root

    required property int keycardState
    required property bool isWrongKeycard
    required property int keycardRemainingPinAttempts
    required property int keycardRemainingPukAttempts
    property string loginError

    required property bool isBiometricsLogin
    required property bool biometricsSuccessful
    required property bool biometricsFailed
    signal biometricsRequested()

    signal pinEditedManually()

    signal detailedErrorPopupRequested()

    signal unblockWithSeedphraseRequested()
    signal unblockWithPukRequested()

    signal loginRequested(string pin)


    function clear() {
        d.wrongPin = false
        pinInputField.clearPin()
    }

    function markAsWrongPin() {
        d.wrongPin = true
        pinInputField.statesInitialization()
    }

    function setPin(pin: string) {
        pinInputField.setPin(pin)
    }

    horizontalPadding: Theme.padding
    verticalPadding: 20

    QtObject {
        id: d
        property bool wrongPin
    }

    background: Rectangle {
        color: StatusColors.transparent
        border.width: 1
        border.color: Theme.palette.baseColor2
        radius: Theme.radius
    }

    contentItem: ColumnLayout {
        spacing: 12
        LoginTouchIdIndicator {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.halfPadding
            id: touchIdIcon
            visible: false
            success: root.biometricsSuccessful
            error: root.biometricsFailed
            onClicked: root.biometricsRequested()
        }
        StatusBaseText {
            Layout.fillWidth: true
            id: infoText
            horizontalAlignment: Qt.AlignHCenter
            elide: Text.ElideRight
            color: Theme.palette.baseColor1
            wrapMode: Text.Wrap
            linkColor: hoveredLink ? Theme.palette.hoverColor(color) : color
            visible: text !== ""
            HoverHandler {
                cursorShape: !!parent.hoveredLink ? Qt.PointingHandCursor : undefined
            }
            onLinkActivated: root.detailedErrorPopupRequested()
        }

        Column {
            id: lockedButtons
            Layout.fillWidth: true
            spacing: 12
            visible: false
            MaybeOutlineButton {
                objectName: "btnUnblockWithPUK"
                width: parent.width
                visible: root.keycardState === Onboarding.KeycardState.BlockedPIN && root.keycardRemainingPukAttempts > 0
                text: qsTr("Unblock with PUK")
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
            }
            MaybeOutlineButton {
                objectName: "btnUnblockWithSeedphrase"
                width: parent.width
                visible: root.keycardState === Onboarding.KeycardState.BlockedPIN || root.keycardState === Onboarding.KeycardState.BlockedPUK
                text: qsTr("Unblock with recovery phrase")
                onClicked: root.unblockWithSeedphraseRequested()
            }
        }
        StatusPinInput {
            Layout.alignment: Qt.AlignHCenter
            id: pinInputField
            objectName: "pinInput"
            validator: StatusIntValidator { bottom: 0; top: 999999 }
            visible: false
            inputMethodHints: Qt.ImhDigitsOnly

            onPinInputChanged: {
                if (pinInput.length === 6) {
                    root.loginRequested(pinInput)
                }
            }
            onPinEditedManually: {
                root.pinEditedManually()
            }

            onVisibleChanged: {
                if (!visible) {
                    return
                }
                //Just delay for states to settle before setting focus or clearing focus
                Qt.callLater(() => {
                    if (visible) {
                        pinInputField.statesInitialization()
                    } else {
                        pinInputField.clearInputFocus()
                    }
                })
            }
        }
    }

    states: [
        // normal/intro states
        State {
            name: "plugin"
            when: root.keycardState === Onboarding.KeycardState.PluginReader && !SQUtils.Utils.isMobile
            PropertyChanges {
                target: infoText
                text: qsTr("Plug in Keycard reader...")
            }
        },
        State {
            name: "insert"
            when: root.keycardState === Onboarding.KeycardState.InsertKeycard && !SQUtils.Utils.isMobile
            PropertyChanges {
                target: infoText
                text: qsTr("Tap or insert your Keycard...")
            }
        },
        State {
            name: "reading"
            when: root.keycardState === Onboarding.KeycardState.ReadingKeycard && !SQUtils.Utils.isMobile
            PropertyChanges {
                target: infoText
                text: qsTr("Reading Keycard...")
            }
        },
        // error states
        State {
            name: "notKeycard"
            when: root.keycardState === Onboarding.KeycardState.NotKeycard
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("Oops this isn't a Keycard.<br>Try using a Keycard instead.")
            }
        },
        State {
            name: "wrongKeycard"
            when: root.isWrongKeycard
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("Wrong Keycard for this profile")
            }
        },
        State {
            name: "genericError"
            when: (root.keycardState === Onboarding.KeycardState.NoPCSCService ||
                  root.keycardState === Onboarding.KeycardState.MaxPairingSlotsReached ) && !SQUtils.Utils.isMobile// TODO add a generic/fallback keycard error here too
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("Issue detecting Keycard.<br>Remove and re-insert reader and Keycard, check no other security keys are plugged in.")
            }
        },
        State {
            name: "maxPairingSlotsReached"
            when: root.keycardState === Onboarding.KeycardState.MaxPairingSlotsReached && SQUtils.Utils.isMobile
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("Max pairing slots reached.")
            }
        },
        State {
            name: "blocked"
            when: root.keycardState === Onboarding.KeycardState.BlockedPIN ||
                  root.keycardState === Onboarding.KeycardState.BlockedPUK
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("Keycard blocked")
            }
            PropertyChanges {
                target: lockedButtons
                visible: true
            }
            PropertyChanges {
                target: pinInputField
                enabled: false
                visible: false
            }
        },
        State {
            name: "empty"
            when: root.keycardState === Onboarding.KeycardState.Empty
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("The scanned Keycard is empty.<br>Use the correct Keycard for this profile.")
            }
        },
        State {
            name: "wrongPin"
            extend: "notEmpty"
            when: root.keycardState === Onboarding.KeycardState.NotEmpty && d.wrongPin
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("PIN incorrect. %n attempt(s) remaining.", "", root.keycardRemainingPinAttempts)
            }
        },
        State {
            name: "errorDuringLogin"
            when: !!root.loginError
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("Login failed. %1").arg("<a href='#details'>" + qsTr("Show details.") + "</a>")
            }
        },
        // exit states
        State {
            name: "notEmpty"
            when: root.keycardState === Onboarding.KeycardState.UnknownReaderState && !d.wrongPin
            PropertyChanges {
                target: infoText
                text: qsTr("Enter Keycard PIN")
            }
            PropertyChanges {
                target: background
                border.color: Theme.palette.primaryColor1
            }
            PropertyChanges {
                target: pinInputField
                visible: true
                enabled: true
            }
            PropertyChanges {
                target: touchIdIcon
                visible: root.isBiometricsLogin
            }
        }
    ]
}
