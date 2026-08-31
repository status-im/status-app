import QtQuick
import QtTest

import StatusQ.Core.Theme
import StatusQ.TestHelpers

import shared.views
import AppLayouts.Onboarding.pages

import utils

Item {
    id: root

    width: 800
    height: 700

    Component {
        id: passwordViewComp

        PasswordView {
            width: 400
            passwordStrengthScoreFunction: root.scoreFor
        }
    }

    Component {
        id: createPasswordPageComp

        CreatePasswordPage {
            width: 800
            height: 700
            passwordStrengthScoreFunction: root.scoreFor
        }
    }

    function scoreFor(password) {
        // Keep score independent of zxcvbn: 10 chars → 0, 11 → 1, …, 14+ → 4
        if (!password || password.length === 0)
            return 0
        return Math.min(Math.max(password.length - 10, 0), 4)
    }

    StatusTestCase {
        name: "PasswordView"

        property PasswordView controlUnderTest: null

        function init() {
            controlUnderTest = createTemporaryObject(passwordViewComp, root)
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)
        }

        function typeInto(objectName, text) {
            const input = findChild(controlUnderTest, objectName)
            verify(!!input)
            mouseClick(input)
            tryCompare(input, "activeFocus", true)
            keyClickSequence(text)
            return input
        }

        function indicator(objectName) {
            const item = findChild(controlUnderTest, objectName)
            verify(!!item)
            return item
        }

        function test_notReadyUntilMinLengthAndMatch() {
            compare(controlUnderTest.ready, false)

            typeInto("passwordViewNewPassword", "short")
            compare(controlUnderTest.ready, false)

            const minChars = findChild(controlUnderTest, "passwordViewMinCharsText")
            verify(!!minChars)
            compare(minChars.text, qsTr("Minimum %n character(s)", "", Constants.minPasswordLength))

            const confirm = findChild(controlUnderTest, "passwordViewNewPasswordConfirm")
            mouseClick(confirm)
            keyClickSequence("short")
            compare(controlUnderTest.ready, false)
        }

        function test_characterClassIndicators() {
            const lower = indicator("passwordComponentIndicator_lowerCase")
            const upper = indicator("passwordComponentIndicator_upperCase")
            const numbers = indicator("passwordComponentIndicator_numbers")
            const symbols = indicator("passwordComponentIndicator_symbols")

            compare(lower.checked, false)
            compare(upper.checked, false)
            compare(numbers.checked, false)
            compare(symbols.checked, false)

            typeInto("passwordViewNewPassword", "abcdefghij")
            compare(lower.checked, true)
            compare(upper.checked, false)
            compare(numbers.checked, false)
            compare(symbols.checked, false)
            compare(lower.text, "✓ " + qsTr("Lower case"))

            const input = findChild(controlUnderTest, "passwordViewNewPassword")
            input.text = "ABCDEFGHIJ"
            compare(lower.checked, false)
            compare(upper.checked, true)
            compare(upper.text, "✓ " + qsTr("Upper case"))

            input.text = "1234567890"
            compare(numbers.checked, true)
            compare(numbers.text, "✓ " + qsTr("Numbers"))

            input.text = "+_!!!!!!!!"
            compare(symbols.checked, true)
            compare(symbols.text, "✓ " + qsTr("Symbols"))

            input.text = "+1_3!48aTq"
            compare(lower.checked, true)
            compare(upper.checked, true)
            compare(numbers.checked, true)
            compare(symbols.checked, true)
        }

        function test_strengthScoreMapsToLabelAndColor_data() {
            return [
                { tag: "very weak", password: "abcdefghij", label: qsTr("Very weak"), color: Theme.palette.dangerColor1 },
                { tag: "weak", password: "abcdefghijk", label: qsTr("Weak"), color: Theme.palette.pinColor1 },
                { tag: "okay", password: "abcdefghijkl", label: qsTr("Okay"), color: Theme.palette.miscColor7 },
                { tag: "good", password: "abcdefghijklm", label: qsTr("Good"), color: Theme.palette.miscColor12 },
                { tag: "very strong", password: "abcdefghijklmn", label: qsTr("Very strong"), color: Theme.palette.successColor1 }
            ]
        }

        function test_strengthScoreMapsToLabelAndColor(data) {
            const input = findChild(controlUnderTest, "passwordViewNewPassword")
            input.text = data.password

            const strength = findChild(controlUnderTest, "passwordStrengthIndicator")
            verify(!!strength)
            tryCompare(strength, "text", data.label)
            compare(strength.fillColor, data.color)
        }

        function test_passwordsMatchEnablesReady() {
            const newInput = findChild(controlUnderTest, "passwordViewNewPassword")
            const confirm = findChild(controlUnderTest, "passwordViewNewPasswordConfirm")

            newInput.text = "ValidPass1!"
            confirm.text = "ValidPass1!"
            compare(controlUnderTest.ready, true)
            compare(controlUnderTest.errorMsgText, "")
        }

        function test_passwordMismatchShowsError() {
            const newInput = findChild(controlUnderTest, "passwordViewNewPassword")
            const confirm = findChild(controlUnderTest, "passwordViewNewPasswordConfirm")

            newInput.text = "ValidPass1!"
            mouseClick(confirm)
            tryCompare(confirm, "activeFocus", true)
            keyClickSequence("Different1!")
            // checkPasswordMatches runs when lengths match
            tryCompare(controlUnderTest, "errorMsgText", qsTr("Passwords don't match"))
            compare(controlUnderTest.ready, false)
        }

        function test_unicodePasswordRejected() {
            const newInput = findChild(controlUnderTest, "passwordViewNewPassword")
            const confirm = findChild(controlUnderTest, "passwordViewNewPasswordConfirm")

            newInput.text = "ValidPass1ä"
            confirm.text = "ValidPass1ä"
            tryCompare(controlUnderTest, "errorMsgText", qsTr("Only ASCII letters, numbers, and symbols are allowed"))
            compare(controlUnderTest.ready, false)
        }
    }

    StatusTestCase {
        name: "CreatePasswordPage"

        function test_confirmButtonDisabledUntilPasswordReady() {
            const page = createTemporaryObject(createPasswordPageComp, root)
            verify(!!page)
            waitForRendering(page)

            const confirmButton = findChild(page, "btnConfirmPassword")
            verify(!!confirmButton)
            compare(confirmButton.enabled, false)

            const newInput = findChild(page, "passwordViewNewPassword")
            const confirmInput = findChild(page, "passwordViewNewPasswordConfirm")
            verify(!!newInput)
            verify(!!confirmInput)

            newInput.text = "short"
            confirmInput.text = "short"
            compare(confirmButton.enabled, false)

            newInput.text = ""
            confirmInput.text = ""
            compare(confirmButton.enabled, false)

            newInput.text = "ValidPass1ä"
            confirmInput.text = "ValidPass1ä"
            compare(confirmButton.enabled, false)

            newInput.text = "ValidPass1!"
            confirmInput.text = "ValidPass1!"
            tryCompare(confirmButton, "enabled", true)
        }
    }
}
