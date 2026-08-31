import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components
import StatusQ.Popups

ColumnLayout {
    id: root

    readonly property bool ready: !d.isTooShort && // min length OK
                                  !d.isTooLong && // max length OK
                                  newPswInput.text === confirmPswInput.text && // passwords matching
                                  errorTxt.text === "" // no errors

    property bool createNewPsw: true
    property string title: createNewPsw ? qsTr("Create a password") : qsTr("Change your password")
    property bool titleVisible: true
    property real titleSize: 22
    property string introText: {
        if (createNewPsw) {
            return qsTr("Create a password to unlock Status on this device & sign transactions.")
        }

        return ""
    }
    property string recoverText: qsTr("You will not be able to recover this password if it is lost.")
    property string strengthenText: qsTr("Minimum %n character(s)", "", Constants.minPasswordLength)
    property bool highSizeIntro: false

    property int contentAlignment: Qt.AlignHCenter

    property var passwordStrengthScoreFunction: (password) => { console.error("passwordStrengthScoreFunction: IMPLEMENT ME") }

    readonly property int zBehind: 1
    readonly property int zFront: 100

    property alias currentPswText: currentPswInput.text
    property alias newPswText: newPswInput.text
    property alias confirmationPswText: confirmPswInput.text
    property alias errorMsgText: errorTxt.text

    signal returnPressed()

    function forceNewPswInputFocus() { newPswInput.forceActiveFocus(Qt.MouseFocusReason) }

    function reset() {
        newPswInput.text = ""
        currentPswInput.text = ""
        confirmPswInput.text = ""
        errorTxt.text = ""

        // Update focus:
        if (SQUtils.Utils.isMobile)
            return

        if(root.createNewPsw)
            newPswInput.forceActiveFocus(Qt.MouseFocusReason)
        else
            currentPswInput.forceActiveFocus(Qt.MouseFocusReason)
    }

    function checkPasswordMatches(onlyIfConfirmPasswordHasFocus = true) {
        if (confirmPswInput.text.length === 0) {
            return
        }

        if (onlyIfConfirmPasswordHasFocus && !confirmPswInput.focus) {
            return
        }

        if(newPswInput.text.length >= Constants.minPasswordLength) {
            if(confirmPswInput.text !== newPswInput.text) {
                errorTxt.text = qsTr("Passwords don't match")
            }
        }
    }

    QtObject {
        id: d

        readonly property var validatorRegexp: /^[!-~]+$/
        readonly property string validatorErrMessage: qsTr("Only ASCII letters, numbers, and symbols are allowed")
        readonly property string passTooLongErrMessage: qsTr("Maximum %n character(s)", "", Constants.maxPasswordLength)

        // Read-only flag that turns true when the component enters a “compact” layout automatically on resize.
        readonly property bool compactMode: root.width < 300

        // Password strength categorization / validation
        function lowerCaseValidator(text) { return (/[a-z]/.test(text)) }
        function upperCaseValidator(text) { return (/[A-Z]/.test(text)) }
        function numbersValidator(text) { return (/\d/.test(text)) }
        // That includes NOT extended ASCII printable symbols less space:
        function symbolsValidator(text) { return (/[!-\/:-@[-`{-~]/.test(text)) }

        function validateCharacterSet(text) {
            if(!(d.validatorRegexp).test(text)) {
                if (!!text)
                    errorTxt.text = d.validatorErrMessage
                return false
            }
            if(isTooLong) {
                return false
            }

            return true
        }

        // Used to convert strength from a given score to a specific category
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

        // Password validation / error message selection:
        function passwordValidation() {
            // 3 rules to validate:
            // * Password is in pwnd passwords database
            if(isInPwndDatabase())
                errorTxt.text = qsTr("Password pwned, shouldn't be used")

            // * Common password
            else if(isCommonPassword())
                errorTxt.text = qsTr("Common password, shouldn't be used")
        }

        function isInPwndDatabase() {
            // "TODO - Nice To Have: Pwnd password validation NOT implemented yet! "
            return false
        }

        function isCommonPassword() {
            // "TODO - Nice To Have: Common password validation NOT implemented yet! "
            return false
        }

        readonly property bool isTooShort: newPswInput.text.length < Constants.minPasswordLength
        readonly property bool isTooLong: newPswInput.text.length > Constants.maxPasswordLength
    }

    implicitWidth: 460
    spacing: Theme.padding
    z: root.zFront

    StatusBaseText {
        Layout.fillWidth: true
        visible: root.titleVisible
        text: root.title
        font.pixelSize: root.titleSize
        font.bold: true
        color: Theme.palette.directColor1
        elide: Text.ElideRight
        wrapMode: Text.Wrap
        maximumLineCount: 2
        horizontalAlignment: root.contentAlignment
    }

    ColumnLayout {
        id: introColumn

        Layout.fillWidth: true
        Layout.topMargin: -6
        Layout.alignment: root.contentAlignment
        spacing: 4

        StatusBaseText {
            Layout.fillWidth: true
            visible: !!text
            text: root.introText
            horizontalAlignment: root.contentAlignment
            font.pixelSize: root.highSizeIntro ? Theme.primaryTextFontSize : Theme.tertiaryTextFontSize
            wrapMode: Text.WordWrap
            color: Theme.palette.baseColor1
        }

        StatusBaseText {
            Layout.fillWidth: true
            text: root.recoverText
            horizontalAlignment: root.contentAlignment
            font.pixelSize: root.highSizeIntro ? Theme.primaryTextFontSize : Theme.tertiaryTextFontSize
            wrapMode: Text.WordWrap
            color: Theme.palette.dangerColor1
        }
    }

    ColumnLayout {
        visible: !root.createNewPsw

        StatusBaseText {
            text: qsTr("Current password")
        }

        StatusPasswordInput {
            id: currentPswInput
            objectName: "passwordViewCurrentPassword"

            property bool showPassword

            z: root.zFront
            Layout.fillWidth: true
            Layout.alignment: root.contentAlignment
            placeholderText: qsTr("Enter current password")
            echoMode: showPassword ? TextInput.Normal : TextInput.Password
            rightPadding: showHideCurrentIcon.width + showHideCurrentIcon.anchors.rightMargin + Theme.padding / 2
            onAccepted: root.returnPressed()

            StatusFlatRoundButton {
                id: showHideCurrentIcon
                visible: currentPswInput.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 16
                width: 24
                height: 24
                icon.name: currentPswInput.showPassword ? "hide" : "show"
                icon.color: Theme.palette.baseColor1

                onClicked: currentPswInput.showPassword = !currentPswInput.showPassword
            }
        }
    }

    StatusModalDivider {
        visible: !root.createNewPsw
        Layout.fillWidth: true
        Layout.alignment: root.contentAlignment
    }

    ColumnLayout {
        z: root.zFront
        Layout.fillWidth: true
        Layout.alignment: root.contentAlignment

        RowLayout {
            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Choose password")
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            Item { Layout.fillWidth: true }

            LayoutItemProxy {
                visible: !d.compactMode

                target: minCharsText
            }
        }

        LayoutItemProxy {
            visible: d.compactMode

            Layout.fillWidth: true

            target: minCharsText
        }

        StatusPasswordInput {
            id: newPswInput
            objectName: "passwordViewNewPassword"

            property bool showPassword

            Layout.alignment: root.contentAlignment
            Layout.fillWidth: true
            placeholderText: qsTr("Type password")
            echoMode: showPassword ? TextInput.Normal : TextInput.Password
            rightPadding: showHideNewIcon.width + showHideNewIcon.anchors.rightMargin + Theme.padding / 2
            hasError: d.isTooLong

            onTextChanged: {
                // Update password checkers
                errorTxt.text = ""

                if(!d.validateCharacterSet(text)) return

                if (text.length === confirmPswInput.text.length) {
                    root.checkPasswordMatches(false)
                }
            }
            onAccepted: root.returnPressed()

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
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: root.contentAlignment

        RowLayout {
            StatusBaseText {
                Layout.fillWidth: true
                text: qsTr("Repeat password")
                elide: Text.ElideRight
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            Item { Layout.fillWidth: true }
            StatusBaseText {
                text: "✓ " + qsTr("Passwords match")
                visible: !!newPswInput.text && !!confirmPswInput.text && // passwords non empty
                         newPswInput.text === confirmPswInput.text && // passwords match
                         !d.isTooShort && !d.isTooLong // first password w/o errors
                font.pixelSize: Theme.tertiaryTextFontSize
                color: Theme.palette.successColor1
            }
        }

        StatusPasswordInput {
            id: confirmPswInput
            objectName: "passwordViewNewPasswordConfirm"

            property bool showPassword

            z: root.zFront
            Layout.fillWidth: true
            Layout.alignment: root.contentAlignment
            placeholderText: qsTr("Type password")
            echoMode: showPassword ? TextInput.Normal : TextInput.Password
            rightPadding: showHideConfirmIcon.width + showHideConfirmIcon.anchors.rightMargin + Theme.padding / 2

            onTextChanged: {
                errorTxt.text = ""

                if(!d.validateCharacterSet(newPswInput.text)) return

                d.passwordValidation();
                if(text.length === newPswInput.text.length) {
                    root.checkPasswordMatches()
                }
            }

            onFocusChanged: {
                // When clicking into the confirmation input, validate if new password:
                if(focus) {
                    d.passwordValidation()
                }
                // When leaving the confirmation input because of the button or other input component is focused, check if password matches
                else {
                    root.checkPasswordMatches(false)
                }
            }
            onAccepted: root.returnPressed()

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
    }

    StatusPasswordStrengthIndicator {
        objectName: "passwordStrengthIndicator"
        Layout.fillWidth: true
        value: newPswInput.text.length
        strength: d.convertStrength(root.passwordStrengthScoreFunction(newPswInput.text))
        from: 0
        to: Constants.minPasswordLength
    }

    Item {
        Layout.fillWidth: true
        implicitHeight: indicators.implicitHeight

        Flow {
            id: indicators
            width: parent.width
            anchors.centerIn: parent
            spacing: Theme.padding
            flow: Flow.LeftToRight


            PasswordComponentIndicator {
                objectName: "passwordComponentIndicator_lowerCase"
                caption: qsTr("Lower case")
                checked: d.lowerCaseValidator(newPswInput.text)
            }

            PasswordComponentIndicator {
                objectName: "passwordComponentIndicator_upperCase"
                caption: qsTr("Upper case")
                checked: d.upperCaseValidator(newPswInput.text)
            }

            PasswordComponentIndicator {
                objectName: "passwordComponentIndicator_numbers"
                caption: qsTr("Numbers")
                checked: d.numbersValidator(newPswInput.text)
            }

            PasswordComponentIndicator {
                objectName: "passwordComponentIndicator_symbols"
                caption: qsTr("Symbols")
                checked: d.symbolsValidator(newPswInput.text)
            }
        }
    }

    StatusBaseText {
        id: errorTxt
        Layout.fillWidth: true
        elide: Text.ElideRight
        horizontalAlignment: root.contentAlignment
        font.pixelSize: Theme.tertiaryTextFontSize
        color: Theme.palette.dangerColor1
        visible: !!text
    }


    // Here there are defined the components used inside layout item proxy components:
    StatusBaseText {
        id: minCharsText
        objectName: "passwordViewMinCharsText"
        text: {
            if (d.isTooLong)
                return d.passTooLongErrMessage
            if (d.isTooShort)
                return root.strengthenText
            return "✓ " + root.strengthenText
        }
        font.pixelSize: Theme.tertiaryTextFontSize
        color: d.isTooLong ? Theme.palette.dangerColor1 : d.isTooShort ? Theme.palette.baseColor1 : Theme.palette.successColor1
        elide: Text.ElideRight
        wrapMode: Text.Wrap
        maximumLineCount: 2
    }
}
