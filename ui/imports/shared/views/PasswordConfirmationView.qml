import QtQuick
import QtQuick.Layouts

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import utils

ColumnLayout {
    id: root

    required property string expectedPassword
    property bool passwordMatch

    signal submit()

    function forceInputFocus() {
        confPswInput.forceActiveFocus(Qt.MouseFocusReason)
    }

    QtObject {
        id: d

        function updatePasswordMatch() {
            root.passwordMatch = confPswInput.text === root.expectedPassword
            if (!root.passwordMatch) {
                errorTxt.text = qsTr("Passwords don't match")
            }
        }
    }

    StatusBaseText {
        Layout.fillWidth: true
        text: qsTr("Have you written down your password?")
        font.bold: true
        color: Theme.palette.directColor1
        font.pixelSize: Theme.fontSize(22)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 4

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("You will never be able to recover your password if you lose it.")
            color: Theme.palette.dangerColor1
            font.pixelSize: Theme.primaryTextFontSize
            wrapMode: Text.WordWrap
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("If you need to, write it using pen and paper and keep in a safe place.")
            color: Theme.palette.baseColor1
            font.pixelSize: Theme.primaryTextFontSize
            wrapMode: Text.WordWrap
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("If you lose your password you will lose access to your Status profile.")
            color: Theme.palette.baseColor1
            font.pixelSize: Theme.primaryTextFontSize
            wrapMode: Text.WordWrap
        }
    }

    StatusPasswordInput {
        id: confPswInput

        property bool showPassword: false

        objectName: "confirmAgainPasswordInput"
        Layout.fillWidth: true
        Layout.maximumWidth: 416
        Layout.alignment: Qt.AlignHCenter
        placeholderText: qsTr("Confirm your password (again)")
        echoMode: showPassword ? TextInput.Normal : TextInput.Password
        validator: RegularExpressionValidator { regularExpression: /^[!-~]+$/ } // That includes NOT extended ASCII printable characters less space
        maximumLength: Constants.maxPasswordLength // a maximum of 100 characters allowed
        rightPadding: showHideCurrentIcon.width + showHideCurrentIcon.anchors.rightMargin + Theme.padding / 2
        onTextChanged: {
            errorTxt.text = ""
            d.updatePasswordMatch()
        }
        Keys.onReturnPressed: {
            root.submit()
        }

        StatusFlatRoundButton {
            id: showHideCurrentIcon
            visible: confPswInput.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 16
            width: 24
            height: 24
            icon.name: confPswInput.showPassword ? "hide" : "show"
            icon.color: Theme.palette.baseColor1

            onClicked: confPswInput.showPassword = !confPswInput.showPassword
        }
    }

    StatusBaseText {
        id: errorTxt
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        Layout.fillHeight: true
        Layout.topMargin: -Theme.halfPadding
        color: Theme.palette.dangerColor1
        font.pixelSize: Theme.tertiaryTextFontSize
    }
}
