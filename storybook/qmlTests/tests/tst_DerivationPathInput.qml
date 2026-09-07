import QtQuick
import QtQuick.Controls
import QtQml
import QtTest

import shared.popups.addaccount.panels
import shared.popups.addaccount.panels.DerivationPathInput

Item {
    id: root
    width: 600
    height: 400

    TestCase {
        name: "DerivationPathInputControllerTests"

        Component {
            id: controllerComponent

            Controller {
                enabledColor: "white"
                frozenColor: "black"
                errorColor: "red"
                warningColor: "orange"
            }
        }

        property Controller controller: null

        function init() {
            controller = createTemporaryObject(controllerComponent, root)
        }

        function test_parseRegularBases_data() {
            return [
                {tag: "Ethereum Standard", base: "m/44'/60'/0'/0", expected: ["m/44'/", "60", "'/", "0", "'/", "0"]},
                {tag: "Custom", base: "m/44'", expected: ["m/44'"]},
                {tag: "Custom with separator", base: "m/44'/", expected: ["m/44'/"]},
                {tag: "Ethereum Ledger", base: "m/44'/60'/0'", expected: ["m/44'/", "60", "'/", "0", "'"]},
                {tag: "Ethereum Ledger Live", base: "m/44'/60'", expected: ["m/44'/", "60", "'"]},
            ]
        }

        function test_parseRegularBases(data) {
            let res = controller.parseDerivationPath(data.base)
            compare(res.length, data.expected.length, `expect same length: ${JSON.stringify(res)} vs ${JSON.stringify(data.expected)}`)
            for (const i in res) {
                compare(data.expected[i], res[i].content)
            }
        }

        function test_parseRegularDerivationPath_data() {
            return [
                {tag: "Ethereum one address index", derivationPath: "m/44'/60'/0'/0/1", expected: ["m/44'/", "60", "'/", "0", "'/", "0", "/", "1"]},
                {tag: "Ethereum two address index", derivationPath: "m/44'/60'/0'/0/1/2", expected: ["m/44'/", "60", "'/", "0", "'/", "0", "/", "1", "/", "2"]},
                {tag: "Ethereum Ledger", derivationPath: "m/44'/60'/0'/1/2", expected: ["m/44'/", "60", "'/", "0", "'/", "1", "/", "2"]},
                {tag: "Ethereum Ledger Live", derivationPath: "m/44'/60'/1'/2/3", expected: ["m/44'/", "60", "'/", "1", "'/", "2", "/", "3"]},
                {tag: "Empty entries", derivationPath: "m/44'/'/'//", expected: ["m/44'/", "", "'/", "", "'/", "", "/", ""]},
                {tag: "Wrong entries", derivationPath: "m/44'/T<'/.?'/;/wrong", expected: ["m/44'/", "T<", "'/", ".?", "'/", ";", "/", "wrong"]},
                {tag: "Custom corner-case coin only", derivationPath: "m/44'/77", expected: ["m/44'/", "77"]},
                {tag: "Custom corner-case hardened coin only", derivationPath: "m/44'/12'", expected: ["m/44'/", "12", "'"]},
                {tag: "Custom corner-case coin and separator", derivationPath: "m/44'/12'/", expected: ["m/44'/", "12", "'/", ""]},
                {tag: "Custom corner-case coin and address", derivationPath: "m/44'/12'/03", expected: ["m/44'/", "12", "'/", "03"]},
                {tag: "Custom corner-case coin and hardened address", derivationPath: "m/44'/12'/03'", expected: ["m/44'/", "12", "'/", "03", "'"]},
                {tag: "Custom corner-case coin, address and separator", derivationPath: "m/44'/12'/03'/", expected: ["m/44'/", "12", "'/", "03", "'/", ""]},
                {tag: "Custom corner-case coin, address and change", derivationPath: "m/44'/12'/03'/83", expected: ["m/44'/", "12", "'/", "03", "'/", "83"]},
                {tag: "Custom corner-case coin, address, change and separator", derivationPath: "m/44'/12'/03'/83/", expected: ["m/44'/", "12", "'/", "03", "'/", "83", "/", ""]},
            ]
        }

        function test_parseRegularDerivationPath(data) {
            let res = controller.parseDerivationPath(data.derivationPath)
            compare(res.length, data.expected.length, `expect same element count for: ${JSON.stringify(res)} vs ${JSON.stringify(data.expected)}`)
            for (const i in res) {
                compare(data.expected[i], res[i].content, `expect same element for [${i}]: ${JSON.stringify(res)} vs ${JSON.stringify(data.expected)}`)
            }
        }
        function test_completeDerivationPath_data() {
            return [
                {tag: "Ethereum", base: "m/44'/60'/0'/0", derivationPath: "m/44'/60'/0'/0/1", expected: ["m/44'/", "60", "'/", "0", "'/", "0", "/", "1"]},
                {tag: "Ending in separator", base: "m/44'/60'/0'/0", derivationPath: "m/44'/60'/0'/0/", expected: ["m/44'/", "60", "'/", "0", "'/", "0", "/", ""]},
                {tag: "Custom", base: "m/44'", derivationPath: "m/44'", expected: ["m/44'/", ""]},
                {tag: "Ethereum Ledger", base: "m/44'", derivationPath: "m/44'/60'/0/1/2", expected: ["m/44'/", "60", "'/", "0", "'/", "1", "/", "2"]},
                {tag: "Broken Ethereum", base: "m/44'", derivationPath: "m/44'/60/0'/0/1/2", expected: ["m/44'/", "60/0", "'/", "0", "/", "1", "/", "2"]},
            ]
        }

        function test_completeDerivationPath(data) {
            let res = controller.completeDerivationPath(data.base, data.derivationPath)
            verify(res.errorMessage.length === 0, `expect no error message, got "${res.errorMessage}"`)
            compare(res.elements.length, data.expected.length, `expect same length for test data entry ${data.name}, ${JSON.stringify(res.elements)} vs ${JSON.stringify(data.expected)}`)
            for (const i in res) {
                compare(data.expected[i], res[i].content)
            }
        }

        function test_parseRegularWrongDerivationPath_data() {
            return [
                {tag: "Other standard", derivationPath: "m/46'/60'/0'/0/1"},
                {tag: "Incomplete", derivationPath: "m/44"},
                {tag: "Ethereum", derivationPath: "'/46'/60'/0'/0/1"},
            ]
        }

        function test_parseRegularWrongDerivationPath(data) {
            let res = controller.parseDerivationPath(data.derivationPath)
            compare(res, null)
        }

        function test_validateAllElements_data() {
            return [
                {tag: "No error", derivationPath: "m/44'/60'/0'/0/1", error: "", warning: ""},
                {tag: "No error regression", derivationPath: "m/44'/", error: "", warning: ""},
                {tag: "Non-ethereum", derivationPath: "m/44'/83'/0'/0/1", error: "", warning: "Non-Ethereum cointype"},
                {tag: "Numbers only", derivationPath: "m/44'/8d3'/0'/0/1", error: "Please enter numbers only", warning: ""},
                {tag: "First address index too big", derivationPath: "m/44'/83'/0'/0/101", error: "Account number must be <100", warning: ""},
                {tag: "Last address index too big", derivationPath: "m/44'/83'/0'/0/1/2/123", error: "Account number must be <100", warning: ""},
            ]
        }

        function test_validateAllElements(data) {
            const res = controller.completeDerivationPath("m/44'", data.derivationPath)
            var validationResult = controller.validateAllElements(res.elements)
            var expectAllOk = true
            if(data.error) {
                verify(validationResult.error, `expect error message, got "${validationResult.error}"`)
                expectAllOk = false
            }
            if(data.warning) {
                verify(validationResult.warning, `expect warning message, got "${validationResult.warning}"`)
                expectAllOk = false
            }
            if(expectAllOk) {
                verify(!validationResult.error, `expect no error message, got "${validationResult.error}"`)
                verify(!validationResult.warning, `expect no warning message, got "${validationResult.warning}"`)
            }
        }

        Component {
            id: testDataElementsComponent
            Item {
                Element { id: base; content: "m/44'/"; startIndex: 0; endIndex: 7; contentType: Element.ContentType.Base }
                Element { id: coin; content: "60"; startIndex: base.endIndex; endIndex: startIndex + content.length; contentType: Element.ContentType.Number }
                Element { id: coinAccSep; content: "'/"; startIndex: coin.endIndex; endIndex: startIndex + content.length; contentType: Element.ContentType.Separator }
                Element { id: acc; content: "777"; startIndex: coinAccSep.endIndex; endIndex: startIndex + content.length; contentType: Element.ContentType.Number }
                Element { id: accChgSep; content: "'/"; startIndex: acc.endIndex; endIndex: startIndex + content.length; contentType: Element.ContentType.Separator }
                Element { id: chg; content: "0"; startIndex: accChgSep.endIndex; endIndex: startIndex + content.length; contentType: Element.ContentType.Number }
                Element { id: chgAccIdxSep; content: "/"; startIndex: chg.endIndex; endIndex: startIndex + content.length; contentType: Element.ContentType.Separator }
                Element { id: accIdx1; content: "1"; startIndex: chgAccIdxSep.endIndex; endIndex: startIndex + content.length; contentType: Element.ContentType.Number }
                Element { id: accIdxSep1; content: "/"; startIndex: accIdx1.endIndex; endIndex: startIndex + content.length; contentType: Element.ContentType.Separator }
                Element { id: accIdx2; content: "2"; startIndex: accIdxSep1.endIndex; endIndex: startIndex + content.length; contentType: Element.ContentType.Number }
                Element { id: accIdxSep2; content: "/"; startIndex: accIdx2.endIndex; endIndex: startIndex + content.length; contentType: Element.ContentType.Separator }
                Element { id: accIdx3; content: "2"; startIndex: accIdxSep2.endIndex; endIndex: startIndex + content.length; contentType: Element.ContentType.Number }
            }
        }

        function test_generateHtml() {
            let res = controller.generateHtmlFromElements(testDataElementsComponent.createObject(root).resources)
            verify(/^<style>(?:\.[a-zA-Z]{[a-zA-Z0-9#:;]+})+<\/style>(?:<span\sclass=["']\w["']>[\/\d'm]+<\/span>)+$/.test(res), `The generated html is valid and optimum (no extra spaces or CSS long names) - "${res}"`)
        }
    }

    Component {
        id: inputComponent
        DerivationPathInput {
            width: 500
        }
    }

    TestCase {
        name: "DerivationPathInputImCommitTests"
        when: windowShown

        property DerivationPathInput control: null

        function init() {
            control = createTemporaryObject(inputComponent, root)
            verify(!!control)
            verify(control.resetDerivationPath("m/44'/60'/0'/0", "m/44'/60'/0'/0/5"))
            control.input.edit.forceActiveFocus()
            tryVerify(() => control.input.edit.activeFocus)
        }

        // Virtual keyboards commit characters through the input method instead
        // of key events; edit.insert() takes the same non-Keys path into the
        // control, making it a faithful stand-in.
        function test_imCommitAppendsDigit() {
            compare(control.derivationPath, "m/44'/60'/0'/0/5")
            control.input.edit.insert(control.input.cursorPosition, "3")
            compare(control.derivationPath, "m/44'/60'/0'/0/53")
        }

        // The mobile repro: delete the last index with backspace (delivered as
        // a key event even by virtual keyboards), then type its replacement
        // (delivered as an IM commit)
        function test_imCommitAfterRemovingLastIndex() {
            keyClick(Qt.Key_Backspace)
            verify(control.derivationPath !== "m/44'/60'/0'/0/5")

            control.input.edit.insert(control.input.cursorPosition, "7")
            compare(control.derivationPath, "m/44'/60'/0'/0/7")
        }

        // Anything but a clean insertion still reverts to the model
        function test_externalReplacementReverted() {
            control.input.edit.selectAll()
            control.input.edit.remove(0, control.input.edit.length)
            compare(control.derivationPath, "m/44'/60'/0'/0/5")
        }
    }
}
