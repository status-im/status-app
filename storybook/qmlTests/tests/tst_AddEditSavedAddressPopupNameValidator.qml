import QtQuick
import QtTest

import AppLayouts.Wallet.popups

import utils

Item {
    id: root

    width: 600
    height: 700

    Component {
        id: popupComponent

        AddEditSavedAddressPopup {
            destroyOnClose: false
            modal: false

            isChecksumValidForAddress: () => true
            getWalletAccount: () => ({})
            getSavedAddress: () => ({})
            remainingCapacityForSavedAddresses: () => 10
            savedAddressNameExists: (name) => name.toLowerCase() === "taken"

            Component.onCompleted: initWithParams({edit: false, name: "", address: "", colorId: ""})
        }
    }

    TestCase {
        name: "AddEditSavedAddressPopupNameValidator"
        when: windowShown

        function setAndValidate(input, text) {
            input.text = text
            input.validate(true)
        }

        function openPopup() {
            const popup = createTemporaryObject(popupComponent, root)
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)

            const input = findChild(popup, "savedAddressNameStatusInput")
            verify(!!input)
            return input
        }

        function test_nameAcceptsLettersAndDigitsOfAnyScript_data() {
            return [
                { tag: "latin",              name: "My Wallet-1_a" },
                { tag: "serbian cyrillic",   name: "Саша Ђенић-ЂЂЧчЋћЖжЉљЊњШш" },
                { tag: "serbian latin",      name: "Saša Đenić-ĐđČčĆćŽžŠš" },
                { tag: "ukrainian",          name: "Ґудзик Їжак Євген" },
                { tag: "german",             name: "Straße Ärger Öl Über" },
                { tag: "french",             name: "Élodie Ça Noël" },
                { tag: "greek",              name: "Αλέξανδρος" },
                { tag: "chinese",            name: "我的钱包" },
                { tag: "japanese",           name: "財布 ワレット さいふ" },
                { tag: "korean",             name: "내 지갑" },
                { tag: "arabic",             name: "محفظتي" },
                { tag: "hebrew",             name: "הארנק שלי" },
                { tag: "hindi (with marks)", name: "मेरा बटुआ" },
                { tag: "thai (with marks)",  name: "กระเป๋า" },
                { tag: "vietnamese",         name: "Ví của tôi" },
                { tag: "unicode digits",     name: "Саша ٣٤٥" },
            ]
        }

        function test_nameAcceptsLettersAndDigitsOfAnyScript(data) {
            const input = openPopup()
            setAndValidate(input, data.name)
            verify(input.valid, `"${data.name}" must be a valid saved address name (error: "${input.errorMessageCmp.text}")`)
            compare(input.errorMessageCmp.text, "")
        }

        function test_nameRejectsPunctuationAndEmojis_data() {
            return [
                { tag: "ascii punctuation", name: "Саша!",  expectedError: Constants.errorMessages.alphanumericalExpanded1RegExp },
                { tag: "dot",               name: "wallet.1", expectedError: Constants.errorMessages.alphanumericalExpanded1RegExp },
                { tag: "double space",      name: "Саша  Ђ", expectedError: Constants.errorMessages.alphanumericalExpanded1RegExp },
                { tag: "cjk punctuation",   name: "我的钱包。", expectedError: Constants.errorMessages.alphanumericalExpanded1RegExp },
                { tag: "emoji",             name: "Саша 🙂", expectedError: Constants.errorMessages.emojRegExp },
            ]
        }

        function test_nameRejectsPunctuationAndEmojis(data) {
            const input = openPopup()
            setAndValidate(input, data.name)
            verify(!input.valid, `"${data.name}" must be an invalid saved address name`)
            compare(input.errorMessageCmp.text, data.expectedError)
        }

        function test_emojiCheckIsStatelessAcrossValidations() {
            const input = openPopup()

            // The emoji regex carries the 'g' flag; consecutive checks must not depend on lastIndex.
            setAndValidate(input, "🙂")
            verify(!input.valid)
            compare(input.errorMessageCmp.text, Constants.errorMessages.emojRegExp)

            setAndValidate(input, "🙂 Саша")
            verify(!input.valid)
            compare(input.errorMessageCmp.text, Constants.errorMessages.emojRegExp)

            setAndValidate(input, "Саша")
            verify(input.valid)
        }
    }
}
