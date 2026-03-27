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

    property bool wrongPin: false
    property int remainingAttempts: -1
    property int maxPinRetries: 3
    property bool submitOnPinComplete: true

    readonly property alias pin: pinInputField.pinInput
    readonly property bool pinValid: pinInputField.pinInput.length === Constants.keycard.general.keycardPinLength && !root.wrongPin

    signal accepted()

    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    contentItem: ColumnLayout {
        spacing: Theme.halfPadding

        Image {
            id: image
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: Constants.keycard.shared.imageHeight
            Layout.preferredWidth: Constants.keycard.shared.imageWidth
            source: root.wrongPin ? Assets.png("keycard/pin/negative")
                                  : Assets.png("keycard/pin/in-progress")
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        StatusBaseText {
            id: title
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("Enter this Keycard's PIN")
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
                if (root.wrongPin)
                    root.wrongPin = false

                if (pinInput.length === pinLen && root.submitOnPinComplete)
                    root.accepted()
            }
        }

        StatusBaseText {
            id: errorInfo
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.wrongPin
            text: qsTr("PIN incorrect")
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.dangerColor1
        }

        StatusBaseText {
            id: attemptsInfo
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.wrongPin && root.remainingAttempts > 0 && root.remainingAttempts < root.maxPinRetries
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
        if (wrongPin)
            pinInputField.statesInitialization()
    }

    Component.onCompleted: {
        pinInputField.statesInitialization()
    }
}
