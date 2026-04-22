import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import utils

Control {
    id: root

    property var passwordStrengthScoreFunction: (password) => { console.error("passwordStrengthScoreFunction: IMPLEMENT ME") }

    property string initialPassword: ""

    readonly property string password: newPswInput.text

    Component.onCompleted: {
        if (!initialPassword)
            return
        newPswInput.text = initialPassword
        confirmPswInput.text = initialPassword
    }

    readonly property bool ready: !d.isTooShort
                                  && !d.isTooLong
                                  && newPswInput.text.length > 0
                                  && newPswInput.text === confirmPswInput.text
                                  && !d.charSetError

    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding
    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding

    QtObject {
        id: d

        readonly property var validatorRegexp: /^[!-~]+$/

        readonly property bool isTooShort: newPswInput.text.length < Constants.minPasswordLength
        readonly property bool isTooLong: newPswInput.text.length > Constants.maxPasswordLength
        readonly property bool charSetError: newPswInput.text.length > 0 && !validatorRegexp.test(newPswInput.text)

        function lowerCaseValidator(text) { return (/[a-z]/.test(text)) }
        function upperCaseValidator(text) { return (/[A-Z]/.test(text)) }
        function numbersValidator(text) { return (/\d/.test(text)) }
        function symbolsValidator(text) { return (/[!-\/:-@[-`{-~]/.test(text)) }

        function convertStrength(score) {
            var strength = StatusPasswordStrengthIndicator.Strength.None
            switch(score) {
            case 0: strength = StatusPasswordStrengthIndicator.Strength.VeryWeak; break
            case 1: strength = StatusPasswordStrengthIndicator.Strength.Weak; break
            case 2: strength = StatusPasswordStrengthIndicator.Strength.SoSo; break
            case 3: strength = StatusPasswordStrengthIndicator.Strength.Good; break
            case 4: strength = StatusPasswordStrengthIndicator.Strength.Great; break
            }
            if(strength > 4)
                strength = StatusPasswordStrengthIndicator.Strength.Great
            return strength
        }
    }

    contentItem: ColumnLayout {

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 2*Theme.xlPadding
            Layout.rightMargin: 2*Theme.xlPadding
            spacing: Theme.padding

            StatusBaseText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: qsTr("Create a password")
                font.weight: Font.Bold
                font.pixelSize: Theme.fontSize(22)
            }

            StatusBaseText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.RichText
                text: qsTr("Create a password to unlock Status on this device & sign transactions. <span style='color:%1;'>You won’t be able to recover password if lost.</span>").arg(Theme.palette.dangerColor1)
                wrapMode: Text.WordWrap
                color: Theme.palette.baseColor1
            }

            StatusPasswordInput {
                id: newPswInput

                property bool showPassword

                Layout.fillWidth: true
                placeholderText: qsTr("New password")
                echoMode: showPassword ? TextInput.Normal : TextInput.Password
                rightPadding: showHideNewIcon.width + showHideNewIcon.anchors.rightMargin + Theme.padding / 2
                hasError: d.isTooLong || d.charSetError

                StatusFlatRoundButton {
                    id: showHideNewIcon
                    visible: newPswInput.text !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    width: 24
                    height: 24
                    icon.name: newPswInput.showPassword ? "hide" : "show"
                    icon.color: Theme.palette.baseColor1

                    onClicked: newPswInput.showPassword = !newPswInput.showPassword
                }

                Component.onCompleted: {
                    forceActiveFocus()
                }
            }

            StatusPasswordStrengthIndicator {
                Layout.fillWidth: true
                value: newPswInput.text.length
                strength: d.convertStrength(root.passwordStrengthScoreFunction(newPswInput.text))
                from: 0
                to: Constants.minPasswordLength
            }

            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("To strengthen your password consider including:")
                font.pixelSize: Theme.tertiaryTextFontSize
                color: Theme.palette.baseColor1
                wrapMode: Text.WordWrap
            }

            Flow {
                Layout.fillWidth: true
                spacing: Theme.padding

                StatusBaseText {
                    readonly property bool checked: d.lowerCaseValidator(newPswInput.text)
                    text: "%1 %2".arg(checked ? "✓" : "+").arg(qsTr("Lower case"))
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: checked ? Theme.palette.successColor1 : Theme.palette.baseColor1
                }

                StatusBaseText {
                    readonly property bool checked: d.upperCaseValidator(newPswInput.text)
                    text: "%1 %2".arg(checked ? "✓" : "+").arg(qsTr("Upper case"))
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: checked ? Theme.palette.successColor1 : Theme.palette.baseColor1
                }

                StatusBaseText {
                    readonly property bool checked: d.numbersValidator(newPswInput.text)
                    text: "%1 %2".arg(checked ? "✓" : "+").arg(qsTr("Numbers"))
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: checked ? Theme.palette.successColor1 : Theme.palette.baseColor1
                }

                StatusBaseText {
                    readonly property bool checked: d.symbolsValidator(newPswInput.text)
                    text: "%1 %2".arg(checked ? "✓" : "+").arg(qsTr("Symbols"))
                    font.pixelSize: Theme.tertiaryTextFontSize
                    color: checked ? Theme.palette.successColor1 : Theme.palette.baseColor1
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.padding
            }

            StatusPasswordInput {
                id: confirmPswInput

                property bool showPassword

                Layout.fillWidth: true
                placeholderText: qsTr("Confirm password")
                echoMode: showPassword ? TextInput.Normal : TextInput.Password
                rightPadding: showHideConfirmIcon.width + showHideConfirmIcon.anchors.rightMargin + Theme.padding / 2
                hasError: confirmPswInput.text.length > 0
                          && newPswInput.text.length > 0
                          && confirmPswInput.text !== newPswInput.text

                StatusFlatRoundButton {
                    id: showHideConfirmIcon
                    visible: confirmPswInput.text !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    width: 24
                    height: 24
                    icon.name: confirmPswInput.showPassword ? "hide" : "show"
                    icon.color: Theme.palette.baseColor1

                    onClicked: confirmPswInput.showPassword = !confirmPswInput.showPassword
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
