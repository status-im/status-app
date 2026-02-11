import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

Item {
    id: root

    property var sharedKeycardModule

    signal validation(bool result)

    QtObject {
        id: d

        property bool allEntriesValid: false

        function processText(text) {
            if(text.length === 0)
                return ""
            if(/(^\s|^\r|^\n)|(\s$|^\r$|^\n$)/.test(text)) {
                return text.trim()
            }
            else if(/\s|\r|\n/.test(text)) {
                return ""
            }
            return text
        }

        function update() {
            let codeEntered = code0.text.length > 0 && code1.text.length > 0

            if (codeEntered && code0.text !== code1.text) {
                errorTxt.text = qsTr("The codes don’t match")
            }
            else {
                errorTxt.text = ""
            }

            d.allEntriesValid = codeEntered && code0.text === code1.text
            if (d.allEntriesValid) {
                root.sharedKeycardModule.setPairingCode(code0.text)
            }
            else {
                root.sharedKeycardModule.setPairingCode("")
            }
            root.validation(d.allEntriesValid)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.xlPadding
        anchors.bottomMargin: Theme.halfPadding
        anchors.leftMargin: Theme.xlPadding
        anchors.rightMargin: Theme.xlPadding
        spacing: Theme.padding
        clip: true

        TitleText {
            id: title
            Layout.preferredHeight: Constants.keycard.general.titleHeight
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Enter a new pairing code")
        }

        StatusBaseText {
            Layout.preferredWidth: code0.width
            Layout.alignment: Qt.AlignCenter
            text: qsTr("Pairing code")
            color: Theme.palette.directColor1
        }

        StatusPasswordInput {
            id: code0

            property bool showPassword: false

            Layout.preferredWidth: Constants.keycard.general.keycardPairingCodeInputWidth
            Layout.alignment: Qt.AlignCenter
            placeholderText: qsTr("Enter code")
            echoMode: showPassword ? TextInput.Normal : TextInput.Password
            rightPadding: showHideIcon0.width + showHideIcon0.anchors.rightMargin + Theme.padding / 2

            onTextChanged: {
                text = d.processText(text)
                d.update()
            }

            onAccepted: {
                if (d.allEntriesValid &&
                        (input.edit.keyEvent === Qt.Key_Return ||
                         input.edit.keyEvent === Qt.Key_Enter)) {
                    event.accepted = true
                    root.sharedKeycardModule.currentState.doPrimaryAction()
                }
            }

            StatusFlatRoundButton {
                id: showHideIcon0
                visible: code0.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 16
                width: 24
                height: 24
                icon.name: code0.showPassword ? "hide" : "show"
                icon.color: Theme.palette.baseColor1

                onClicked: code0.showPassword = !code0.showPassword
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.padding
        }

        StatusBaseText {
            Layout.preferredWidth: code1.width
            Layout.alignment: Qt.AlignCenter
            text: qsTr("Confirm pairing code")
            color: Theme.palette.directColor1
        }

        StatusPasswordInput {
            id: code1

            property bool showPassword: false

            Layout.preferredWidth: Constants.keycard.general.keycardPairingCodeInputWidth
            Layout.alignment: Qt.AlignCenter
            placeholderText: qsTr("Confirm code")
            echoMode: showPassword ? TextInput.Normal : TextInput.Password
            rightPadding: showHideIcon1.width + showHideIcon1.anchors.rightMargin + Theme.padding / 2

            onTextChanged: {
                text = d.processText(text)
                d.update()
            }

            onAccepted: {
                if (d.allEntriesValid &&
                        (input.edit.keyEvent === Qt.Key_Return ||
                         input.edit.keyEvent === Qt.Key_Enter)) {
                    event.accepted = true
                    root.sharedKeycardModule.currentState.doPrimaryAction()
                }
            }

            StatusFlatRoundButton {
                id: showHideIcon1
                visible: code1.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 16
                width: 24
                height: 24
                icon.name: code1.showPassword ? "hide" : "show"
                icon.color: Theme.palette.baseColor1

                onClicked: code1.showPassword = !code1.showPassword
            }
        }

        StatusBaseText {
            id: errorTxt
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.dangerColor1
        }
    }
}
