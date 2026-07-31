import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls

import utils

Control {
    id: root

    objectName: "enterPairingPasswordStep"

    // Set when a previous attempt with a user-supplied password was rejected by the card.
    property bool wrongPairingPassword: false

    readonly property alias pairingPassword: pairingPasswordInput.text
    readonly property bool pairingPasswordValid: pairingPasswordInput.text !== "" && !root.wrongPairingPassword

    signal accepted()

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
            source: root.wrongPairingPassword ? Assets.png("keycard/pin/negative")
                                              : Assets.png("keycard/pin/in-progress")
            fillMode: Image.PreserveAspectFit
            mipmap: true
        }

        StatusBaseText {
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("Enter Keycard pairing password")
            font.weight: Font.Bold
            font.pixelSize: Theme.fontSize(22)
        }

        StatusBaseText {
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: qsTr("This Keycard was set up with a custom pairing password. Enter it to continue.")
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.baseColor1
        }

        StatusPasswordInput {
            id: pairingPasswordInput
            objectName: "keycardPairingPasswordInput"
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            placeholderText: qsTr("Pairing password")
            selectByMouse: true
            focus: !SQUtils.Utils.isMobile

            onTextChanged: root.wrongPairingPassword = false

            onAccepted: {
                if (root.pairingPasswordValid)
                    root.accepted()
            }
        }

        StatusBaseText {
            Layout.alignment: Qt.AlignCenter
            Layout.maximumWidth: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.wrongPairingPassword
            text: qsTr("Pairing password incorrect")
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.dangerColor1
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }

    Component.onCompleted: {
        pairingPasswordInput.forceActiveFocus(Qt.MouseFocusReason)
    }
}
