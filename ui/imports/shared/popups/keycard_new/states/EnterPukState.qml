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
        EnterPuk,
        CreatePuk,
        RepeatPuk
    }

    property int mode: EnterPukState.Mode.EnterPuk

    property alias pukInput: pukInputField.pinInput

    // RepeatPuk mode
    property string pukToMatch: ""
    readonly property bool pukMismatch: {
        if (root.mode !== EnterPukState.Mode.RepeatPuk) {
            return false
        }
        if (pukInputField.pinInput.length < root.pukToMatch.length) {
            for (let i = 0; i < pukInputField.pinInput.length; i++) {
                if (root.pukToMatch[i] !== pukInputField.pinInput[i]) {
                    return true
                }
            }
            return false
        }
        return root.pukToMatch !== pukInputField.pinInput
    }

    readonly property bool pukValid: {
        const full = pukInputField.pinInput.length === Constants.keycard.general.keycardPukLength
        if (root.mode === EnterPukState.Mode.RepeatPuk)
            return full && !root.pukMismatch
        return full
    }

    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    QtObject {
        id: d
        property bool invalidCharEntered: false
    }

    contentItem: ColumnLayout {
        spacing: Theme.padding

        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Constants.keycard.shared.imageHeight
            Layout.preferredWidth: Constants.keycard.shared.imageWidth
            source: root.mode === EnterPukState.Mode.EnterPuk
                    || root.mode === EnterPukState.Mode.RepeatPuk && root.pukMismatch
                    || d.invalidCharEntered
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
                case EnterPukState.Mode.EnterPuk: return qsTr("Enter PUK")
                case EnterPukState.Mode.RepeatPuk: return qsTr("Repeat your Keycard PUK")
                default: return qsTr("Choose a Keycard PUK")
                }
            }
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
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
                d.invalidCharEntered = false
            }

            onInvalidInput: {
                d.invalidCharEntered = true
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: !!text
            text: {
                if (d.invalidCharEntered) {
                    return qsTr("Use numbers only")
                }
                if (root.mode === EnterPukState.Mode.RepeatPuk && root.pukMismatch) {
                    return qsTr("PUK doesn't match")
                }
                return ""
            }
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.dangerColor1
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    Component.onCompleted: {
        pukInputField.statesInitialization()
    }
}
