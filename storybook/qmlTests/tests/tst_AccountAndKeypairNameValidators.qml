import QtQuick
import QtTest

import AppLayouts.Profile.popups
import shared.popups.keycard_new.states

import utils

Item {
    id: root

    width: 600
    height: 700

    Component {
        id: renameAccountModalComponent

        RenameAccountModal {
            accountName: "Sample Account"
            accountColorId: Constants.walletAccountColors.orange
            destroyOnClose: false
        }
    }

    Component {
        id: enterKeyPairNameStateComponent

        EnterKeyPairNameState {
            width: 400
        }
    }

    TestCase {
        name: "AccountAndKeypairNameValidators"
        when: windowShown

        function setAndValidate(input, text) {
            input.text = text
            input.validate(true)
        }

        function test_minLengthConstants() {
            compare(Constants.addAccountPopup.keyPairAccountNameMinLength, 1)
            compare(Constants.keypair.nameLengthMin, 1)
            compare(Constants.displayName.nameLengthMin, 5)
        }

        function test_accountName_emptyIsInvalidOneCharIsValid() {
            const popup = createTemporaryObject(renameAccountModalComponent, root)
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)

            const input = popup.contentItem.accountNameInput
            verify(!!input)

            setAndValidate(input, "")
            verify(!input.valid, "empty account name must be invalid")
            compare(input.errorMessageCmp.text,
                    qsTr("Account name must be at least %n character(s)", "",
                         Constants.addAccountPopup.keyPairAccountNameMinLength))

            setAndValidate(input, "a")
            verify(input.valid, "a 1-character account name must be valid")

            popup.close()
        }

        function test_keypairName_emptyIsInvalidOneCharIsValid() {
            const state = createTemporaryObject(enterKeyPairNameStateComponent, root)
            verify(!!state)
            waitForRendering(state)

            const input = findChild(state, "keycardKeyPairNameInput")
            verify(!!input)

            setAndValidate(input, "")
            verify(!input.valid, "empty key pair name must be invalid")
            compare(input.errorMessageCmp.text,
                    qsTr("Key pair must be at least %n character(s)", "",
                         Constants.keypair.nameLengthMin))

            setAndValidate(input, "a")
            verify(input.valid, "a 1-character key pair name must be valid")
        }

        function test_keypairName_acceptsAnyScript_data() {
            return [
                { tag: "serbian cyrillic", name: "Кључ Ђорђе-1" },
                { tag: "serbian latin",    name: "Ključ Đorđe_1" },
                { tag: "ukrainian",        name: "Ключ Їжак" },
                { tag: "german",           name: "Schlüssel Straße" },
                { tag: "chinese",          name: "我的密钥" },
                { tag: "japanese",         name: "キーペア さいふ" },
                { tag: "korean",           name: "내 키" },
                { tag: "arabic",           name: "مفتاحي" },
                { tag: "hindi",            name: "मेरी कुंजी" },
            ]
        }

        function test_keypairName_acceptsAnyScript(data) {
            const state = createTemporaryObject(enterKeyPairNameStateComponent, root)
            verify(!!state)
            waitForRendering(state)

            const input = findChild(state, "keycardKeyPairNameInput")
            verify(!!input)

            setAndValidate(input, data.name)
            verify(input.valid, `"${data.name}" must be a valid key pair name (error: "${input.errorMessageCmp.text}")`)
        }

        function test_keypairName_rejectsPunctuation() {
            const state = createTemporaryObject(enterKeyPairNameStateComponent, root)
            verify(!!state)
            waitForRendering(state)

            const input = findChild(state, "keycardKeyPairNameInput")
            verify(!!input)

            setAndValidate(input, "Кључ!")
            verify(!input.valid)
            compare(input.errorMessageCmp.text, Constants.errorMessages.alphanumericalExpandedRegExp)
        }
    }
}
