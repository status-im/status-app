import QtQuick
import QtTest

import StatusQ
import StatusQ.Controls
import StatusQ.Controls.Validators

import StatusQ.TestHelpers

Item {
    id: root

    width: 300
    height: 100

    function loadControl(test, sourceComponent) {
        let testItem = test.createTemporaryObject(sourceComponent, root)
        test.verify(test.waitForRendering(testItem))
        test.mouseClick(testItem)
        return testItem
    }

    TestCase {
        id: regexTC

        property StatusInput testControl: null

        name: "StatusInput-RegexValidationTest"

        when: windowShown

        Component {
            id: defaultComponent

            StatusInput {
                label: "Control under test"
                charLimit: 30
                placeholderText: `Must match regex(${validators[0].regularExpression.toString()}) and <= 30 chars`

                anchors.fill: parent
                focus: true

                validators: [
                    StatusRegularExpressionValidator {
                        regularExpression: /^[0-9A-Za-z_$\-\s]*$/
                    }
                ]
            }
        }

        //
        // Test guards

        function init() {
            qtOuput.restartCapturing()
            regexTC.testControl = root.loadControl(regexTC, defaultComponent)
        }

        //
        // Tests
        function test_initial_empty_is_valid() {
            verify(!regexTC.testControl.valid, "Expected valid input")

            verify(qtOuput.qtOuput().length === 0, `No output expected. Found:\n"${qtOuput.qtOuput()}"\n`)
        }

        function test_regex_validation() {
            TestUtils.pressKeyAndWait(regexTC, regexTC.testControl, Qt.Key_1)
            verify(regexTC.testControl.valid, "Expected valid input")
            TestUtils.pressKeyAndWait(regexTC, regexTC.testControl, Qt.Key_Ampersand)
            verify(!regexTC.testControl.valid, "Expected invalid input")

            verify(qtOuput.qtOuput().length === 0, `No output expected. Found:\n"${qtOuput.qtOuput()}"\n`)
        }

        function test_regex_validation_unicode() {
            // StatusRegularExpressionValidator evaluates through PCRE2 (RXValidator), so Unicode
            // property classes work and match letters/digits of any script
            regexTC.testControl.validators[0].regularExpression = /^[\p{L}\p{M}\p{N}\s]+$/
            regexTC.testControl.validationMode = StatusInput.ValidationMode.Always

            // (no Indic samples here: font shaping logs "OpenType support missing" and trips the no-output guard)
            for (const text of ["Ђорђе Ћурчић", "Straße", "我的钱包", "ワレット", "Ђорђе ٣٤٥"]) {
                regexTC.testControl.text = text
                regexTC.testControl.validate(true)
                verify(regexTC.testControl.valid, `"${text}" expected to be valid`)
            }
            for (const text of ["Ђорђе!", "我的钱包。", "🙂", "a_b"]) {
                regexTC.testControl.text = text
                regexTC.testControl.validate(true)
                verify(!regexTC.testControl.valid, `"${text}" expected to be invalid`)
            }

            verify(qtOuput.qtOuput().length === 0, `No output expected. Found:\n"${qtOuput.qtOuput()}"\n`)
        }

        function test_no_invalid_input() {
            skip("Test outdated. Needs to be reviewed and fixed.")

            regexTC.testControl.validationMode = StatusInput.ValidationMode.IgnoreInvalidInput

            verify(regexTC.testControl.valid, "Expected valid input")
            verify(regexTC.testControl.text.length === 0, "Expected no input")
            TestUtils.pressKeyAndWait(regexTC, regexTC.testControl, Qt.Key_2)
            verify(regexTC.testControl.valid, "Expected valid input")
            verify(regexTC.testControl.text === "2", "Expect one character")
            TestUtils.pressKeyAndWait(regexTC, regexTC.testControl, Qt.Key_Ampersand)
            verify(regexTC.testControl.valid, "Expected invalid input")
            verify(regexTC.testControl.text === "2", "Expect the same input")

            verify(qtOuput.qtOuput().length === 0, `No output expected. Found:\n"${qtOuput.qtOuput()}"\n`)
        }

        // Use case expected in case new validation changes are enabled with old invalid data
        function test_user_can_delete_initial_invalid_input() {
            const appendInvalidChars = "#@!*"

            regexTC.testControl.text = "invalid $" + appendInvalidChars
            TestUtils.pressKeyAndWait(regexTC, regexTC.testControl, Qt.Key_End)
            verify(!regexTC.testControl.valid, "Expected invalid input due to characters not matching")
            // Delete invalid characters to get a valid text
            for(let i = 0; i < appendInvalidChars.length; ++i)
                TestUtils.pressKeyAndWait(regexTC, regexTC.testControl, Qt.Key_Backspace)
            verify(regexTC.testControl.valid, "Expected valid input")

            verify(qtOuput.qtOuput().length === 0, `No output expected. Found:\n"${qtOuput.qtOuput()}"\n`)
        }
    }

    TestCase {
        id: bindedTC

        property StatusInput testControl: null

        name: "StatusInput-BindedValuesTest"
        when: windowShown

        property QtObject dataObject: QtObject {
            property string text: "Test text"
            property string emoji: "👍"
            property string color: "#FF0000"
        }

        Component {
            id: bindedTextComponent

            StatusInput {
                charLimit: 10
                input.isIconSelectable: true
                placeholderText: qsTr("Enter an account name...")
                text: bindedTC.dataObject.text
                input.asset.emoji: bindedTC.dataObject.emoji
                input.asset.color: bindedTC.dataObject.color

                anchors.fill: parent
                focus: true

                validators: [
                    StatusMinLengthValidator {
                        errorMessage: qsTr("You need to enter an account name")
                        minLength: 1
                    },
                    StatusRegularExpressionValidator {
                        regularExpression: /^[^<>]+$/
                        errorMessage: qsTr("This is not a valid account name")
                    }
                ]
            }
        }

        //
        // Test guards

        function init() {
            bindedTC.testControl = root.loadControl(regexTC, bindedTextComponent)
        }

        //
        // Tests
        function test_assigning_valid_value_works() {
            qtOuput.restartCapturing()

            verify(!testControl.valid, "Expected input not validated yet")
            testControl.validationMode = StatusInput.ValidationMode.Always
            verify(waitForRendering(testControl))
            verify(testControl.valid, "Expected valid input")
            bindedTC.dataObject.text = "Test<New"
            verify(!testControl.valid, "Expected valid input")

            verify(qtOuput.qtOuput().length === 0, `No output expected. Found:\n"${qtOuput.qtOuput()}"\n`)
        }

        // regression test for https://github.com/status-im/status-desktop/issues/16479
        function test_paste_text() {
            verify(!!testControl)

            const textToPaste = "1234567890abcdef" // 16 chars
            ClipboardUtils.setText(textToPaste)

            // clear
            testControl.input.edit.clear()
            testControl.charLimit = 0

            keySequence(StandardKey.Paste)

            // verify we can paste the full text
            compare(testControl.input.edit.length, textToPaste.length)
            compare(testControl.input.edit.text, textToPaste)
            compare(testControl.input.dirty, true)

            // clear again, and set a lower limit
            testControl.input.edit.clear()
            testControl.charLimit = 10

            keySequence(StandardKey.Paste)

            // verify we can paste (some) text and it gets truncated to the charLimit
            compare(testControl.input.edit.length, testControl.charLimit)
            compare(testControl.input.edit.text, textToPaste.slice(0, testControl.charLimit))
        }
    }

    MonitorQtOutput {
        id: qtOuput
    }
}
