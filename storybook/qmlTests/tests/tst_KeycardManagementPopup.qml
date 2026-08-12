import QtQuick
import QtQuick.Controls

import QtTest

import utils

import shared.popups.keycard_new

Item {
    id: root

    width: 600
    height: 700

    QtObject {
        id: mockStore

        property string keycardState: "ready"
        property bool keycardStatusAvailable: true
        property int remainingPinAttempts: 3
        property int remainingPukAttempts: 5
        property int availableSlots: 5
        property string keycardUid: "keycard-uid-1"
        property string keyUid: "profile-key-uid"
        property string cardMetadataName: "My Keycard"
        property string cardMetadataWalletAccountsJson: "[]"
        property var keyPairItem: null
        property string userProfileKeyUid: "profile-key-uid"
        property string userProfilePubKey: "0xpub"
        property bool isProfileMigratedToColdWallet: false

        property var calls: []

        function record(name, args) {
            calls = calls.concat([{ name: name, args: args }])
        }

        function prepare() {}
        function teardown() {}

        function startGetMetadata(pin, pairingPassword) { record("startGetMetadata", [pin, pairingPassword]) }
        function startFactoryReset(keycardUid) { record("startFactoryReset", [keycardUid]) }
        function startUnblockKeycardUsingPuk(newPin, puk, pairingPassword) { record("startUnblockKeycardUsingPuk", [newPin, puk, pairingPassword]) }
        function startUnblockKeycardUsingRecoveryPhrase(newPin, seedPhrase, metadataName, metadataAccountsJson) {}
        function startImportingKeyPair(pin, seedPhrase, metadataName, metadataAccounts) {}
        function startMigratingNonProfileKeypairToKeycard(password, pin, seedPhrase) {}
        function startMigratingProfileKeypairToKeycard(password, pin, seedPhrase) {}
        function startMigratingProfileKeypairUsingExistingKeycard(password, pin, seedPhrase, pairingPassword) {}
        function startAddingKeyPairToStatusFromKeycard(pin, keyUid, metadataName, metadataAccounts, pairingPassword) {
            record("startAddingKeyPairToStatusFromKeycard", [pin, keyUid, metadataName, metadataAccounts, pairingPassword])
        }
        function startStopUsingKeycardForKeyPair(keyUid, seedPhrase, newPassword) {}
        function startStopUsingKeycardForProfileKeyPair(seedPhrase, newPassword) {}
        function startChangeKeycardPIN(currentPin, newPin, pairingPassword) { record("startChangeKeycardPIN", [currentPin, newPin, pairingPassword]) }
        function startChangeKeycardPUK(currentPin, newPuk, pairingPassword) { record("startChangeKeycardPUK", [currentPin, newPuk, pairingPassword]) }
        function startRenameKeycard(currentPin, newName, metadataAccountsJson, pairingPassword) {
            record("startRenameKeycard", [currentPin, newName, metadataAccountsJson, pairingPassword])
        }
        function startAsyncLogin(keyUid, pin, generateXPub, pairingPassword) { record("startAsyncLogin", [keyUid, pin, generateXPub, pairingPassword]) }

        function getKeyUidForSeedPhrase(seedPhrase) { return "seed-key-uid" }
        function generateMnemonic() { return "" }
        function getMnemonic() { return "" }
        function isMnemonicBackedUp() { return true }
        function isKnownKeyUid(keyUid) { return true }
        function isKeypairMigratedToColdWallet(keyUid) { return false }
        function getKeyPairNameForKeyUid(keyUid) { return "Profile" }
        function getKeyPairAccountPathsJsonForKeyUid(keyUid) { return "[]" }
        function resolveKeyPairItemForKeyUid(keyUid) { return null }
        function remainingKeypairCapacity() { return 5 }
        function remainingAccountCapacity() { return 5 }
        function prepareKeyPairModel() {}
        function signOutAndQuit() {}

        signal keycardInteractionSuccessfullyCompleted()
        signal keycardGetMetadataSuccess()
        signal keycardGetMetadataError(string error)
        signal keycardFactoryResetSuccess()
        signal keycardFactoryResetError(string error)
        signal keycardImportKeyPairSuccess()
        signal keycardImportKeyPairError(string error)
        signal keycardAsyncLoginSuccess(string dataJson)
        signal keycardAsyncLoginError(string error)
        signal keycardMoveKeyPairSuccess()
        signal keycardMoveKeyPairError(string error)
        signal keycardMoveProfileKeyPairSuccess()
        signal keycardMoveProfileKeyPairError(string error)
        signal keycardAddKeyPairSuccess()
        signal keycardAddKeyPairError(string error)
        signal stopUsingKeycardForKeyPairSuccess()
        signal stopUsingKeycardForKeyPairError(string error)
        signal stopUsingKeycardForProfileKeyPairSuccess()
        signal stopUsingKeycardForProfileKeyPairError(string error)
        signal keycardChangePinSuccess()
        signal keycardChangePinError(string error)
        signal keycardChangePukSuccess()
        signal keycardChangePukError(string error)
        signal keycardRenameSuccess()
        signal keycardRenameError(string error)
        signal keycardUnblockSuccess()
        signal keycardUnblockError(string error)
    }

    Component {
        id: componentUnderTest

        KeycardManagementPopup {
            flow: Constants.keycard.flow.readKeycard
            keycardUid: mockStore.keycardUid
            keyUid: mockStore.keyUid
            cardMetadataName: mockStore.cardMetadataName
            cardMetadataWalletAccountsJson: mockStore.cardMetadataWalletAccountsJson
            store: mockStore
            closePolicy: Popup.NoAutoClose
            passwordStrengthScoreFunction: (password) => 4
        }
    }

    property var popup

    SignalSpy {
        id: metadataResultSpy
        target: root.popup
        signalName: "metadataResult"
    }

    TestCase {
        name: "KeycardManagementPopup_pairingPassword"
        when: windowShown

        readonly property string pairingErrorText: "Card not ready (state: pairing-error)"
        readonly property string testPin: "123456"

        function init() {
            mockStore.calls = []
            mockStore.keycardState = "ready"
            mockStore.keycardUid = "keycard-uid-1"
            popup = createTemporaryObject(componentUnderTest, root)
            verify(!!popup)
            popup.open()
            metadataResultSpy.clear()
        }

        function cleanup() {
            if (popup)
                popup.close()
        }

        function pairingPasswordInput() {
            return findChild(popup, "keycardPairingPasswordInput")
        }

        function pairingStep() {
            return findChild(popup, "enterPairingPasswordStep")
        }

        function submitPairingPassword() {
            pairingStep().accepted()
        }

        function launchReadKeycard() {
            const pinInput = findChild(popup, "keycardManagementPinInput")
            verify(!!pinInput, "expected the PIN step to be shown")
            pinInput.setPin(testPin)
            tryVerify(() => mockStore.calls.length === 1, 3000)
        }

        function test_firstAttemptUsesDefaultPairingPassword() {
            launchReadKeycard()

            const call = mockStore.calls[0]
            compare(call.name, "startGetMetadata")
            compare(call.args[0], testPin)
            compare(call.args[1], "", "the first attempt must use the default pairing password")
        }

        function test_pairingErrorShowsPasswordStep() {
            launchReadKeycard()
            mockStore.keycardGetMetadataError(pairingErrorText)

            tryVerify(() => !!pairingPasswordInput(), 3000,
                      "expected the pairing password step to be shown")

            verify(!pairingStep().pairingPasswordValid,
                   "an empty pairing password must not be submittable")
        }

        function test_pairingErrorStateShowsPasswordStepEvenWhenOperationSucceeds() {
            launchReadKeycard()
            mockStore.keycardState = "pairing-error"
            mockStore.keycardGetMetadataSuccess()

            tryVerify(() => !!pairingPasswordInput(), 3000,
                      "expected the pairing password step to be shown")
            compare(metadataResultSpy.count, 0, "must not navigate away from the flow")
        }

        function test_pairingErrorStateDoesNotPromptBeforeAnyAttempt() {
            mockStore.keycardState = "pairing-error"
            wait(50)

            verify(!pairingPasswordInput(),
                   "pairing password step must not appear before the flow has attempted anything")
        }

        function test_wrongPinErrorDoesNotShowPasswordStep() {
            launchReadKeycard()
            mockStore.keycardGetMetadataError("Wrong PIN")
            wait(50)

            verify(!pairingPasswordInput(), "pairing password step must not appear for a wrong PIN")
        }

        function test_noAvailablePairingSlotsDoesNotShowPasswordStep() {
            launchReadKeycard()
            mockStore.keycardGetMetadataError("Card not ready (state: no-available-pairing-slots)")
            wait(50)

            verify(!pairingPasswordInput(),
                   "pairing password step must not appear when all pairing slots are taken")
        }

        function test_retryReInvokesSameCallWithPassword() {
            launchReadKeycard()
            const firstCall = mockStore.calls[0]

            mockStore.keycardGetMetadataError(pairingErrorText)
            tryVerify(() => !!pairingPasswordInput(), 3000)

            pairingPasswordInput().text = "MyCustomPass"
            verify(pairingStep().pairingPasswordValid,
                   "a non-empty pairing password must enable the footer button")
            submitPairingPassword()

            tryVerify(() => mockStore.calls.length === 2, 3000,
                      "expected the original operation to be re-invoked")

            const retry = mockStore.calls[1]
            compare(retry.name, firstCall.name)
            compare(retry.args[0], firstCall.args[0], "the retry must reuse the original PIN")
            compare(retry.args[1], "MyCustomPass", "the retry must carry the entered pairing password")
        }

        function test_retryIsBlockedWhenCardWasSwapped() {
            launchReadKeycard()

            mockStore.keycardGetMetadataError(pairingErrorText)
            tryVerify(() => !!pairingPasswordInput(), 3000)

            mockStore.keycardUid = "keycard-uid-2"

            pairingPasswordInput().text = "MyCustomPass"
            submitPairingPassword()
            wait(600)

            compare(mockStore.calls.length, 1, "a swapped card must not be retried with the previous card's password")
        }

        function test_secondFailureMarksPasswordAsWrong() {
            launchReadKeycard()

            mockStore.keycardGetMetadataError(pairingErrorText)
            tryVerify(() => !!pairingPasswordInput(), 3000)

            pairingPasswordInput().text = "WrongPass"
            submitPairingPassword()
            tryVerify(() => mockStore.calls.length === 2, 3000)

            mockStore.keycardGetMetadataError(pairingErrorText)
            tryVerify(() => !!findChild(popup, "enterPairingPasswordStep"), 3000)

            const step = findChild(popup, "enterPairingPasswordStep")
            verify(step.wrongPairingPassword,
                   "a repeated pairing error while holding a password means that password was wrong")
        }
    }

    Component {
        id: popupFactory

        KeycardManagementPopup {
            keycardUid: mockStore.keycardUid
            keyUid: mockStore.keyUid
            cardMetadataName: mockStore.cardMetadataName
            cardMetadataWalletAccountsJson: mockStore.cardMetadataWalletAccountsJson
            store: mockStore
            closePolicy: Popup.NoAutoClose
            passwordStrengthScoreFunction: (password) => 4
        }
    }

    TestCase {
        name: "KeycardManagementPopup_changePin"
        when: windowShown

        readonly property string currentPin: "123456"
        readonly property string newPin: "654321"
        readonly property string mismatchedPin: "111111"

        function init() {
            mockStore.calls = []
            mockStore.keycardState = "ready"
            mockStore.keycardUid = "keycard-uid-1"
            popup = createTemporaryObject(popupFactory, root, {
                                              flow: Constants.keycard.flow.changePin
                                          })
            verify(!!popup)
            popup.open()
        }

        function cleanup() {
            if (popup)
                popup.close()
        }

        function pinInput() {
            return findChild(popup, "keycardManagementPinInput")
        }

        function pinTitle() {
            return findChild(popup, "keycardPinStepTitle")
        }

        function pinError() {
            return findChild(popup, "keycardPinStepError")
        }

        function enterPin(pin) {
            const input = pinInput()
            verify(!!input, "expected a PIN step")
            input.setPin(pin)
        }

        function test_startsOnEnterCurrentPin() {
            compare(pinTitle().text, "Enter Keycard PIN")
        }

        function test_happyPathChangesPin() {
            enterPin(currentPin)
            tryVerify(() => pinTitle().text === "Enter new PIN", 3000)

            enterPin(newPin)
            tryVerify(() => pinTitle().text === "Repeat new PIN", 3000)

            enterPin(newPin)
            tryVerify(() => mockStore.calls.length === 1, 3000)

            const call = mockStore.calls[0]
            compare(call.name, "startChangeKeycardPIN")
            compare(call.args[0], currentPin)
            compare(call.args[1], newPin)
            compare(call.args[2], "", "change PIN starts with the default pairing password")

            mockStore.keycardChangePinSuccess()

            tryVerify(() => {
                          const title = findChild(popup, "keycardProgressTitle")
                          return !!title && title.text === "Keycard PIN has been changed"
                      }, 3000)
            compare(findChild(popup, "keycardProgressMessage").text,
                    "New PIN is required to interact with Keycard.")
        }

        function test_repeatPinMismatchShowsError() {
            enterPin(currentPin)
            tryVerify(() => pinTitle().text === "Enter new PIN", 3000)

            enterPin(newPin)
            tryVerify(() => pinTitle().text === "Repeat new PIN", 3000)

            enterPin(mismatchedPin)

            tryVerify(() => pinError().visible, 3000)
            compare(pinError().text, "PIN doesn't match")
            compare(mockStore.calls.length, 0, "mismatch must not start the change-PIN operation")
        }
    }

    TestCase {
        name: "KeycardManagementPopup_setOrChangePuk"
        when: windowShown

        readonly property string currentPin: "123456"
        readonly property string newPuk: "123456789012"
        readonly property string mismatchedPuk: "999999999999"

        function init() {
            mockStore.calls = []
            mockStore.keycardState = "ready"
            mockStore.keycardUid = "keycard-uid-1"
            popup = createTemporaryObject(popupFactory, root, {
                                              flow: Constants.keycard.flow.setOrChangePuk
                                          })
            verify(!!popup)
            popup.open()
        }

        function cleanup() {
            if (popup)
                popup.close()
        }

        function pinInput() { return findChild(popup, "keycardManagementPinInput") }
        function pukInput() { return findChild(popup, "keycardManagementPukInput") }
        function pukTitle() { return findChild(popup, "keycardPukStepTitle") }
        function nextButton() { return findChild(popup, "keycardManagementNextButton") }

        function enterPin(pin) {
            const input = pinInput()
            verify(!!input)
            input.setPin(pin)
        }

        function enterPukAndNext(puk) {
            const input = pukInput()
            verify(!!input, "expected a PUK step")
            input.setPin(puk)
            tryVerify(() => nextButton().enabled, 3000)
            nextButton().clicked()
        }

        function test_happyPathSetsPuk() {
            enterPin(currentPin)
            tryVerify(() => !!pukTitle() && pukTitle().text === "Choose a Keycard PUK", 3000)

            enterPukAndNext(newPuk)
            tryVerify(() => pukTitle().text === "Repeat your Keycard PUK", 3000)

            enterPukAndNext(newPuk)
            tryVerify(() => mockStore.calls.length === 1, 3000)

            const call = mockStore.calls[0]
            compare(call.name, "startChangeKeycardPUK")
            compare(call.args[0], currentPin)
            compare(call.args[1], newPuk)
            compare(call.args[2], "")

            mockStore.keycardChangePukSuccess()
            tryVerify(() => {
                          const title = findChild(popup, "keycardProgressTitle")
                          return !!title && title.text === "Keycard’s PUK successfully set"
                      }, 3000)
        }

        function test_repeatPukMismatchShowsError() {
            enterPin(currentPin)
            tryVerify(() => !!pukTitle() && pukTitle().text === "Choose a Keycard PUK", 3000)

            enterPukAndNext(newPuk)
            tryVerify(() => pukTitle().text === "Repeat your Keycard PUK", 3000)

            pukInput().setPin(mismatchedPuk)
            tryVerify(() => findChild(popup, "keycardPukStepError").visible, 3000)
            compare(findChild(popup, "keycardPukStepError").text, "PUK doesn't match")
            compare(mockStore.calls.length, 0)
        }
    }

    TestCase {
        name: "KeycardManagementPopup_rename"
        when: windowShown

        readonly property string currentPin: "123456"
        readonly property string newName: "Renamed Card"

        function init() {
            mockStore.calls = []
            mockStore.keycardState = "ready"
            mockStore.keycardUid = "keycard-uid-1"
            mockStore.cardMetadataName = "My Keycard"
            popup = createTemporaryObject(popupFactory, root, {
                                              flow: Constants.keycard.flow.rename
                                          })
            verify(!!popup)
            popup.open()
        }

        function cleanup() {
            if (popup)
                popup.close()
        }

        function test_happyPathRenamesKeycard() {
            const pinInput = findChild(popup, "keycardManagementPinInput")
            verify(!!pinInput)
            pinInput.setPin(currentPin)

            tryVerify(() => !!findChild(popup, "keycardKeyPairNameInput"), 3000)
            const nameInput = findChild(popup, "keycardKeyPairNameInput")
            nameInput.text = newName

            const next = findChild(popup, "keycardManagementNextButton")
            tryVerify(() => next.visible && next.enabled, 3000)
            compare(next.text, "Rename")
            next.clicked()

            tryVerify(() => mockStore.calls.length === 1, 3000)
            const call = mockStore.calls[0]
            compare(call.name, "startRenameKeycard")
            compare(call.args[0], currentPin)
            compare(call.args[1], newName)
            compare(call.args[2], mockStore.cardMetadataWalletAccountsJson)
            compare(call.args[3], "")

            mockStore.keycardRenameSuccess()
            tryVerify(() => {
                          const title = findChild(popup, "keycardProgressTitle")
                          return !!title && title.text === "Keycard has been renamed"
                      }, 3000)
            compare(findChild(popup, "keycardProgressMessage").text, "New name: Renamed Card")
        }
    }

    TestCase {
        name: "KeycardManagementPopup_addKeyPairToStatus"
        when: windowShown

        readonly property string pin: "123456"

        function init() {
            mockStore.calls = []
            mockStore.keycardState = "ready"
            mockStore.keycardUid = "keycard-uid-1"
            mockStore.keyUid = "profile-key-uid"
            mockStore.cardMetadataName = "My Keycard"
            popup = createTemporaryObject(popupFactory, root, {
                                              flow: Constants.keycard.flow.addKeyPairToStatus
                                          })
            verify(!!popup)
            popup.open()
        }

        function cleanup() {
            if (popup)
                popup.close()
        }

        function test_happyPathAddsKeyPair() {
            findChild(popup, "keycardManagementPinInput").setPin(pin)

            tryVerify(() => {
                          const title = findChild(popup, "keycardKeyPairNameTitle")
                          return !!title && title.text === "Name your key pair"
                      }, 3000)
            compare(findChild(popup, "keycardKeyPairNameInput").text, "My Keycard")

            const next = findChild(popup, "keycardManagementNextButton")
            tryVerify(() => next.enabled, 3000)
            next.clicked()

            tryVerify(() => !!findChild(popup, "keycardManageAccountNameInput"), 3000)
            findChild(popup, "keycardManageAccountNameInput").text = "Account One"
            tryVerify(() => next.enabled && next.text === "Continue", 3000)
            next.clicked()

            tryVerify(() => mockStore.calls.length === 1, 3000)
            const call = mockStore.calls[0]
            compare(call.name, "startAddingKeyPairToStatusFromKeycard")
            compare(call.args[0], pin)
            compare(call.args[1], "profile-key-uid")
            compare(call.args[2], "My Keycard")
            verify(call.args[3].indexOf("Account One") !== -1)
            compare(call.args[4], "")

            mockStore.keycardAddKeyPairSuccess()
            tryVerify(() => {
                          const title = findChild(popup, "keycardProgressTitle")
                          return !!title && title.text === "Key pair has been added to Status"
                      }, 3000)
            compare(findChild(popup, "keycardProgressMessage").text,
                    "Now you can sign with this key pair using Keycard.")
        }
    }

    TestCase {
        name: "KeycardManagementPopup_factoryReset"
        when: windowShown

        function init() {
            mockStore.calls = []
            mockStore.keycardState = "ready"
            mockStore.keycardUid = "keycard-uid-1"
            popup = createTemporaryObject(popupFactory, root, {
                                              flow: Constants.keycard.flow.factoryReset
                                          })
            verify(!!popup)
            popup.open()
        }

        function cleanup() {
            if (popup)
                popup.close()
        }

        function test_happyPathFactoryResets() {
            const checkbox = findChild(popup, "keycardFactoryResetConfirmCheckbox")
            const resetButton = findChild(popup, "keycardManagementFactoryResetButton")
            verify(!!checkbox)
            verify(!!resetButton)
            verify(!resetButton.enabled)

            checkbox.checked = true
            tryVerify(() => resetButton.enabled, 3000)
            resetButton.clicked()

            tryVerify(() => mockStore.calls.length === 1, 3000)
            compare(mockStore.calls[0].name, "startFactoryReset")
            compare(mockStore.calls[0].args[0], "keycard-uid-1")

            mockStore.keycardFactoryResetSuccess()
            tryVerify(() => {
                          const title = findChild(popup, "keycardProgressTitle")
                          return !!title && title.text === "Keycard has been reset"
                      }, 3000)
            compare(findChild(popup, "keycardProgressMessage").text, "Keycard is now empty.")
        }
    }

    TestCase {
        name: "KeycardManagementPopup_unblockWithPuk"
        when: windowShown

        readonly property string newPin: "654321"
        readonly property string puk: "123456789012"

        function init() {
            mockStore.calls = []
            mockStore.keycardState = "blocked-pin"
            mockStore.keycardUid = "keycard-uid-1"
            popup = createTemporaryObject(popupFactory, root, {
                                              flow: Constants.keycard.flow.unblockWithPuk
                                          })
            verify(!!popup)
            popup.open()
        }

        function cleanup() {
            if (popup)
                popup.close()
        }

        function test_happyPathUnblocksWithPuk() {
            tryVerify(() => findChild(popup, "keycardPinStepTitle").text === "Enter new PIN", 3000)
            findChild(popup, "keycardManagementPinInput").setPin(newPin)

            tryVerify(() => findChild(popup, "keycardPinStepTitle").text === "Repeat new PIN", 3000)
            findChild(popup, "keycardManagementPinInput").setPin(newPin)

            tryVerify(() => findChild(popup, "keycardPukStepTitle").text === "Enter PUK", 3000)
            findChild(popup, "keycardManagementPukInput").setPin(puk)
            const next = findChild(popup, "keycardManagementNextButton")
            tryVerify(() => next.enabled, 3000)
            next.clicked()

            tryVerify(() => mockStore.calls.length === 1, 3000)
            const call = mockStore.calls[0]
            compare(call.name, "startUnblockKeycardUsingPuk")
            compare(call.args[0], newPin)
            compare(call.args[1], puk)
            compare(call.args[2], "")

            mockStore.keycardUnblockSuccess()
            tryVerify(() => {
                          const title = findChild(popup, "keycardProgressTitle")
                          return !!title && title.text === "Keycard has been unblocked"
                      }, 3000)
            compare(findChild(popup, "keycardProgressMessage").text,
                    "You can now use your Keycard again")
        }
    }

    TestCase {
        name: "KeycardManagementPopup_unblockWithRecoveryPhrase"
        when: windowShown

        readonly property string newPin: "654321"

        function init() {
            mockStore.calls = []
            mockStore.keycardState = "blocked-pin"
            mockStore.keycardUid = "keycard-uid-1"
            popup = createTemporaryObject(popupFactory, root, {
                                              flow: Constants.keycard.flow.unblockWithRecoveryPhrase
                                          })
            verify(!!popup)
            popup.open()
        }

        function cleanup() {
            if (popup)
                popup.close()
        }

        function test_reachesRecoveryPhraseStep() {
            findChild(popup, "keycardManagementPinInput").setPin(newPin)
            tryVerify(() => findChild(popup, "keycardPinStepTitle").text === "Repeat new PIN", 3000)
            findChild(popup, "keycardManagementPinInput").setPin(newPin)

            tryVerify(() => {
                          const title = findChild(popup, "keycardSeedPhraseStepTitle")
                          return !!title && title.text === "Enter recovery phrase"
                      }, 3000)
            compare(mockStore.calls.length, 0,
                    "must not start unblock until the recovery phrase is submitted")
        }
    }
}
