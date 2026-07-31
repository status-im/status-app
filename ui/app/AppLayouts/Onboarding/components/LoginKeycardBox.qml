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

    signal unblockRequested()

    signal loginRequested(string pin)

    signal pairingPasswordSubmitted()

    readonly property alias pairingPassword: pairingPasswordInput.text

    function clear() {
        d.wrongPin = false
        pinInputField.clearPin()
        pairingPasswordInput.clear()
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
        readonly property bool pairingPasswordRequired: root.keycardState === Onboarding.KeycardState.PairingPasswordRequired
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
            id: touchIdIcon
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.halfPadding
            visible: false
            success: root.biometricsSuccessful
            error: root.biometricsFailed
            onClicked: root.biometricsRequested()
        }

        StatusPinInput {
            id: pinInputField
            Layout.alignment: Qt.AlignHCenter
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

        StatusBaseText {
            id: infoText
            Layout.fillWidth: true
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

        StatusPasswordInput {
            id: pairingPasswordInput
            objectName: "keycardPairingPasswordInput"
            Layout.fillWidth: true
            visible: false
            placeholderText: qsTr("Pairing password")
            selectByMouse: true

            onAccepted: {
                if (text !== "")
                    root.pairingPasswordSubmitted()
            }
        }

        MaybeOutlineButton {
            id: pairingPasswordButton
            objectName: "btnSubmitPairingPassword"
            Layout.fillWidth: true
            visible: false
            enabled: pairingPasswordInput.text !== ""
            text: qsTr("Continue")
            onClicked: root.pairingPasswordSubmitted()
        }

        MaybeOutlineButton {
            id: unblockButton
            objectName: "btnUnblock"
            Layout.fillWidth: true
            visible: false
            text: qsTr("Unblock")
            onClicked: root.unblockRequested()
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
            name: "insertMobile"
            when: root.keycardState === Onboarding.KeycardState.InsertKeycard && SQUtils.Utils.isMobile
            extend: "notEmpty"
        },
        State {
            name: "cancelledMobile"
            when: root.keycardState === Onboarding.KeycardState.Cancelled && SQUtils.Utils.isMobile
            extend: "notEmpty"
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
            extend: "notEmpty"
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("This isn't a Keycard.<br>Remove card and insert a Keycard.")
            }
        },
        State {
            name: "wrongKeycard"
            when: root.isWrongKeycard
            extend: "notEmpty"
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("Wrong Keycard for this profile")
            }
        },
        State {
            name: "genericError"
            when: root.keycardState === Onboarding.KeycardState.NoPCSCService && !SQUtils.Utils.isMobile
            extend: "notEmpty"
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("Issue detecting Keycard.<br>Re-scan Keycard.")
            }
        },
        State {
            name: "pairingPasswordRequired"
            when: d.pairingPasswordRequired
            PropertyChanges {
                target: infoText
                text: qsTr("This Keycard was set up with a custom pairing password. Enter it to continue.")
            }
            PropertyChanges {
                target: background
                border.color: Theme.palette.primaryColor1
            }
            PropertyChanges {
                target: pinInputField
                visible: false
            }
            PropertyChanges {
                target: pairingPasswordInput
                visible: true
                enabled: true
            }
            PropertyChanges {
                target: pairingPasswordButton
                visible: true
            }
        },
        State {
            name: "maxPairingSlotsReached"
            when: root.keycardState === Onboarding.KeycardState.MaxPairingSlotsReached
            extend: "notEmpty"
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("No free pairing slots on this Keycard.<br>You can use it with previously paired installations.")
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
                target: unblockButton
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
            extend: "notEmpty"
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("The scanned Keycard is empty.<br>Scan the correct Keycard for this profile.")
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
            extend: "notEmpty"
            PropertyChanges {
                target: infoText
                color: Theme.palette.dangerColor1
                text: qsTr("Login failed. %1").arg("<a href='#details'>" + qsTr("Show details.") + "</a>")
            }
        },
        // exit states
        State {
            name: "notEmpty"
            // Mobile UnknownReaderState just means the keycard was never tapped, so we show the PIN input
            when: (root.keycardState === Onboarding.KeycardState.UnknownReaderState) || (root.keycardState === Onboarding.KeycardState.NotEmpty) && !d.wrongPin
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
