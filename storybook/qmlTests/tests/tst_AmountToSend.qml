import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QtTest

import StatusQ

import shared.popups.send.views

Item {
    id: root

    Component {
        id: componentUnderTest

        AmountToSend {}
    }

    property AmountToSend amountToSend

    SignalSpy {
        id: amountChangedSpy
        target: amountToSend
        signalName: "amountChanged"
    }

    TestCase {
        name: "AmountToSend"
        when: windowShown

        function type(key, times = 1) {
            for (let i = 0; i < times; i++) {
                keyClick(key)
            }
        }

        function init() {
            amountToSend = createTemporaryObject(componentUnderTest, root)
        }

        function cleanup() {
            amountChangedSpy.clear()
        }

        function test_empty() {
            compare(amountToSend.valid, false)
            compare(amountToSend.empty, true)
            compare(amountToSend.amount, "0")
            compare(amountToSend.fiatMode, false)
        }

        // the input cannot elide, so the font must shrink as far as the value
        // needs — the number may never be cut off mid-digit
        function test_longAmountShrinksFontToFit() {
            const textField = findChild(amountToSend, "amountToSend_textField")
            verify(!!textField)

            amountToSend.multiplierIndex = 18

            // content wider than the field makes it scroll with the cursor,
            // pushing the leading digits out of view — so the fit has to hold
            // against the actual width at the rendered font size
            function verifyFullyVisible() {
                waitForRendering(textField)
                verify(textField.contentWidth <= textField.width,
                       "amount scrolled out of view: contentWidth %1 > width %2 at %3px"
                       .arg(textField.contentWidth).arg(textField.width)
                       .arg(textField.font.pixelSize))
            }

            for (const width of [200, 300, 460]) {
                amountToSend.width = width

                amountToSend.setValue("1")
                const baseSize = textField.font.pixelSize
                verifyFullyVisible()

                // a full-precision value with an integral digit, as the amount
                // slider produces; on the narrow widths it can only fit by
                // shrinking the font
                amountToSend.setValue("8.254888888888888888")
                if (width < 400)
                    verify(textField.font.pixelSize < baseSize)
                verifyFullyVisible()

                // an absurdly long typed value still stays fully visible
                amountToSend.setValue("123456789012345678901234567890.123456789012345678")
                verifyFullyVisible()
            }
        }

        function test_settingValueInCryptoMode() {
            const textField = findChild(amountToSend, "amountToSend_textField")

            amountToSend.multiplierIndex = 3
            amountToSend.setValue("2.5")

            compare(textField.text, "2.5")
            compare(amountToSend.amount, "2500")
            compare(amountToSend.valid, true)

            amountToSend.setValue("2.12345678")

            compare(textField.text, "2.123")
            compare(amountToSend.amount, "2123")
            compare(amountToSend.valid, true)

            amountToSend.setValue("2.1239")

            compare(textField.text, "2.124")
            compare(amountToSend.amount, "2124")
            compare(amountToSend.valid, true)

            amountToSend.setValue(".1239")

            compare(textField.text, "0.124")
            compare(amountToSend.amount, "124")
            compare(amountToSend.valid, true)

            amountToSend.setValue("1.0000")

            compare(textField.text, "1")
            compare(amountToSend.amount, "1000")
            compare(amountToSend.valid, true)

            amountToSend.setValue("0.0000")

            compare(textField.text, "0")
            compare(amountToSend.amount, "0")
            compare(amountToSend.valid, true)

            amountToSend.setValue("x")

            compare(textField.text, "NaN")
            compare(amountToSend.amount, "0")
            compare(amountToSend.valid, false)

            // exceeding maxium allowed integral part
            amountToSend.setValue("1234567890000")
            compare(textField.text, "1234567890000")
            compare(amountToSend.amount, "1234567890000000")
            verify(amountToSend.valid)
        }

        function test_settingValueInFiatMode() {
            const textField = findChild(amountToSend, "amountToSend_textField")
            const mouseArea = findChild(amountToSend, "amountToSend_mouseArea")

            amountToSend.cryptoPrice = 0.5
            amountToSend.multiplierIndex = 3

            mouseClick(mouseArea)
            compare(amountToSend.fiatMode, true)

            amountToSend.setValue("2.5")

            compare(textField.text, "2.50")
            compare(amountToSend.amount, "5000")
            compare(amountToSend.valid, true)

            amountToSend.setValue("2.12345678")

            compare(textField.text, "2.12")
            compare(amountToSend.amount, "4240")
            compare(amountToSend.valid, true)

            amountToSend.setValue("2.129")

            compare(textField.text, "2.13")
            compare(amountToSend.amount, "4260")
            compare(amountToSend.valid, true)

            // exceeding maxium allowed integral part
            amountToSend.setValue("1234567890000")
            compare(textField.text, "1234567890000.00")
            compare(amountToSend.amount, "2469135780000000")
            compare(amountToSend.valid, true)
        }

        function test_switchingMode() {
            const textField = findChild(amountToSend, "amountToSend_textField")
            const mouseArea = findChild(amountToSend, "amountToSend_mouseArea")

            amountToSend.cryptoPrice = 0.5
            amountToSend.multiplierIndex = 3

            amountToSend.setValue("10.5")
            compare(amountToSend.amount, "10500")

            mouseClick(mouseArea)
            compare(amountToSend.fiatMode, true)
            compare(textField.text, "5.25")
            compare(amountToSend.amount, "10500")

            mouseClick(mouseArea)
            compare(amountToSend.fiatMode, false)
            compare(textField.text, "10.5")
            compare(amountToSend.amount, "10500")

            mouseClick(mouseArea)
            compare(amountToSend.fiatMode, true)
            amountToSend.cryptoPrice = 0.124
            amountToSend.setValue("1")
            compare(textField.text, "1.00")

            mouseClick(mouseArea)
            compare(amountToSend.fiatMode, false)
            compare(textField.text, "8.065")
            compare(amountToSend.amount, "8065")
        }

        function test_setRawValueIsAlwaysCrypto() {
            const textField = findChild(amountToSend, "amountToSend_textField")
            const mouseArea = findChild(amountToSend, "amountToSend_mouseArea")

            amountToSend.cryptoPrice = 0.5
            amountToSend.multiplierIndex = 3

            amountToSend.setRawValue("10500")
            compare(textField.text, "10.5")
            compare(amountToSend.amount, "10500")

            mouseClick(mouseArea)
            compare(amountToSend.fiatMode, true)

            // base units are a crypto quantity, so fiat mode has to convert them;
            // writing back the value already held must be a no-op, not another
            // division by the price
            amountToSend.setRawValue("10500")
            compare(textField.text, "5.25")
            compare(amountToSend.amount, "10500")

            amountToSend.setRawValue("3000")
            compare(textField.text, "1.50")
            compare(amountToSend.amount, "3000")
        }

        function test_fiatModeNeedsAPriceToSwitchInto() {
            const mouseArea = findChild(amountToSend, "amountToSend_mouseArea")

            amountToSend.cryptoPrice = 0
            verify(!mouseArea.enabled)
            mouseClick(mouseArea)
            compare(amountToSend.fiatMode, false)

            // switching back out never needs one
            amountToSend.cryptoPrice = 0.5
            mouseClick(mouseArea)
            compare(amountToSend.fiatMode, true)
            amountToSend.cryptoPrice = 0
            verify(mouseArea.enabled)
            mouseClick(mouseArea)
            compare(amountToSend.fiatMode, false)
        }

        function test_clear() {
            const textField = findChild(amountToSend, "amountToSend_textField")

            amountToSend.setValue("10.5")
            amountToSend.clear()

            compare(amountToSend.amount, "0")
            compare(textField.text, "")
        }

        function test_localeAndDecimalPoint() {
            verify(!!amountToSend)

            // set a different locale, thus a different decimal separator
            amountToSend.locale = Qt.locale("cs_CZ")
            tryCompare(amountToSend.locale, "name", "cs_CZ")
            tryCompare(amountToSend, "decimalPoint", ",") // "," is the default decimal separator for cs_CZ locale

            const textField = findChild(amountToSend, "amountToSend_textField")
            verify(!!textField)

            amountToSend.setValue("2.5")
            tryCompare(textField, "text", "2,5")
            verify(amountToSend.valid)
        }

        function test_dotTypedInCommaLocale() {
            amountToSend.multiplierIndex = 18
            amountToSend.locale = Qt.locale("pl_PL")

            tryCompare(amountToSend, "decimalPoint", ",")

            const textField = findChild(amountToSend, "amountToSend_textField")
            verify(!!textField)
            textField.forceActiveFocus()

            keyClick(Qt.Key_1)
            keyClick(Qt.Key_Period)
            keyClick(Qt.Key_5)

            tryCompare(textField, "text", "1,5")
            verify(amountToSend.valid)
            compare(amountToSend.delocalized, "1.5")
            compare(amountToSend.amount, "1500000000000000000")
        }

        function test_delocalizedProperty() {
            amountToSend.multiplierIndex = 3

            amountToSend.setValue("2.5")
            compare(amountToSend.delocalized, "2.5")

            amountToSend.locale = Qt.locale("de_DE")
            tryCompare(amountToSend, "decimalPoint", ",")
            amountToSend.setValue("2.5")

            const textField = findChild(amountToSend, "amountToSend_textField")
            tryCompare(textField, "text", "2,5")
            compare(amountToSend.delocalized, "2.5")
            compare(amountToSend.amount, "2500")
        }

        function test_pasteCommaInCommaLocale() {
            amountToSend.multiplierIndex = 18
            amountToSend.locale = Qt.locale("pl_PL")
            tryCompare(amountToSend, "decimalPoint", ",")

            ClipboardUtils.setText("1,5")
            const textField = findChild(amountToSend, "amountToSend_textField")
            verify(!!textField)
            verify(textField.canPaste)
            mouseClick(textField)
            keySequence(StandardKey.Paste)

            tryCompare(textField, "text", "1,5")
            verify(amountToSend.valid)
            compare(amountToSend.delocalized, "1.5")
            compare(amountToSend.amount, "1500000000000000000")
        }

        function test_pasteChangesAmount() {
            compare(amountToSend.valid, false)
            compare(amountToSend.empty, true)
            compare(amountToSend.amount, "0")

            ClipboardUtils.setText("1.0005")
            const textField = findChild(amountToSend, "amountToSend_textField")
            verify(!!textField)

            verify(textField.canPaste)
            mouseClick(textField)
            keySequence(StandardKey.Paste)
            compare(textField.text, "1.0005")

            compare(amountToSend.valid, true)
            compare(amountToSend.empty, false)
            compare(amountToSend.amount, "1000500000000000000")

            compare(amountChangedSpy.count, 1)
        }
    }
}
