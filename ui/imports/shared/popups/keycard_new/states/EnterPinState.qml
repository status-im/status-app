import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators

import utils

Control {
    id: root

    enum Mode {
        EnterPin,
        CreatePin,
        RepeatPin
    }

    property int mode: EnterPinState.Mode.EnterPin

    property alias pinInput: pinInputField.pinInput

    // EnterPin mode
    property bool wrongPin: false
    property int remainingAttempts: -1

    // RepeatPin mode
    property string pinToMatch: ""
    readonly property bool pinMismatch: {
        if (root.mode !== EnterPinState.Mode.RepeatPin) {
            return false
        }
        if (pinInputField.pinInput.length < root.pinToMatch.length) {
            for (let i = 0; i < pinInputField.pinInput.length; i++) {
                if (root.pinToMatch[i] !== pinInputField.pinInput[i]) {
                    return true
                }
            }
            return false
        }
        return root.pinToMatch !== pinInputField.pinInput
    }

    readonly property bool pinComplete: {
        const full = pinInputField.pinInput.length === Constants.keycard.general.keycardPinLength
        if (root.mode === EnterPinState.Mode.EnterPin)
            return full && !root.wrongPin
        if (root.mode === EnterPinState.Mode.RepeatPin)
            return full && !root.pinMismatch
        return full
    }

    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Constants.keycard.shared.imageHeight
            Layout.preferredWidth: Constants.keycard.shared.imageWidth
            source: (root.mode === EnterPinState.Mode.EnterPin && root.wrongPin)
                    || (root.mode === EnterPinState.Mode.RepeatPin && root.pinMismatch)
                    ? Assets.png("keycard/pin/negative")
                    : Assets.png("keycard/pin/in-progress")
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: {
                switch(root.mode) {
                case EnterPinState.Mode.CreatePin: return qsTr("Enter new PIN")
                case EnterPinState.Mode.RepeatPin: return qsTr("Repeat new PIN")
                default: return qsTr("Enter Keycard PIN")
                }
            }
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
        }

        StatusPinInput {
            id: pinInputField
            Layout.fillWidth: true
            Layout.maximumWidth: implicitWidth
            Layout.alignment: Qt.AlignHCenter
            validator: StatusIntValidator { bottom: 0; top: 999999 }
            pinLen: Constants.keycard.general.keycardPinLength

            onPinInputChanged: {
                if (root.mode === EnterPinState.Mode.EnterPin && root.wrongPin)
                    root.wrongPin = false
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.mode === EnterPinState.Mode.EnterPin && root.wrongPin
                     || root.mode === EnterPinState.Mode.RepeatPin && root.pinMismatch
            text: {
                if (root.mode === EnterPinState.Mode.RepeatPin && root.pinMismatch) {
                    return qsTr("PIN doesn't match")
                }
                return qsTr("PIN incorrect")
            }
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.dangerColor1
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.mode === EnterPinState.Mode.EnterPin
                     && root.wrongPin
                     && root.remainingAttempts > 0
                     && root.remainingAttempts < 3
            text: qsTr("%n attempt(s) remaining", "", root.remainingAttempts)
            font.pixelSize: Theme.tertiaryTextFontSize
            color: root.remainingAttempts === 1 ? Theme.palette.dangerColor1
                                                : Theme.palette.baseColor1
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    onWrongPinChanged: {
        if (root.mode === EnterPinState.Mode.EnterPin && wrongPin)
            pinInputField.statesInitialization()
    }

    Component.onCompleted: {
        pinInputField.statesInitialization()
    }
}
