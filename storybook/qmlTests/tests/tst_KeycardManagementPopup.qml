import QtQuick
import QtQuick.Controls

import QtTest

import utils

import shared.popups.keycard_new 1.0

/*!
    Covers the custom pairing password flow: cards provisioned outside the app (e.g. on the
    Keycard shell) reject the default pairing password, and the popup has to ask the user for
    theirs and re-run the *same* operation with the *same* arguments rather than abandoning the
    flow and sending the user back to re-reading the card.

    The re-invocation is driven by a stored `d.lastInvocation` callable, so the assertion that
    matters most is argument-for-argument equality between the original call and the retry.
*/
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

        // Every invocation, so a test can assert the retry matches the original call exactly.
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
            // readKeycard launches its operation from a single PIN entry, which makes it the
            // cheapest flow to drive end to end.
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

        // What a composite operation returns when the card rejects the pairing password: the
        // session state is embedded in the error text, which is how the popup recognises it.
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

        // Submission is owned by the popup's shared primary footer button, which has no
        // objectName to bind to, so drive the step's action directly — that is exactly what the
        // footer button's onClicked does.
        function submitPairingPassword() {
            pairingStep().accepted()
        }

        // Enters the PIN, which launches startGetMetadata after the popup's 500ms debounce.
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

            // Nothing typed yet, so the footer button this drives stays disabled.
            verify(!pairingStep().pairingPasswordValid,
                   "an empty pairing password must not be submittable")
        }

        function test_pairingErrorStateShowsPasswordStepEvenWhenOperationSucceeds() {
            // Reading a card without a PIN can come back "successful" while the card was never
            // paired; only the reported state says so. Leaving the popup then would strand the
            // user on a details view built from an unpaired card.
            launchReadKeycard()
            mockStore.keycardState = "pairing-error"
            mockStore.keycardGetMetadataSuccess()

            tryVerify(() => !!pairingPasswordInput(), 3000,
                      "expected the pairing password step to be shown")
            compare(metadataResultSpy.count, 0, "must not navigate away from the flow")
        }

        function test_pairingErrorStateDoesNotPromptBeforeAnyAttempt() {
            // Nothing has been attempted yet, so there would be nothing to retry.
            mockStore.keycardState = "pairing-error"
            wait(50)

            verify(!pairingPasswordInput(),
                   "pairing password step must not appear before the flow has attempted anything")
        }

        function test_wrongPinErrorDoesNotShowPasswordStep() {
            // Guards against the new branch swallowing unrelated errors.
            launchReadKeycard()
            mockStore.keycardGetMetadataError("Wrong PIN")
            wait(50)

            verify(!pairingPasswordInput(), "pairing password step must not appear for a wrong PIN")
        }

        function test_noAvailablePairingSlotsDoesNotShowPasswordStep() {
            // Not recoverable by entering a password, so it keeps its own terminal handling.
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
            // Everything but the pairing password must be identical to the original call.
            compare(retry.args[0], firstCall.args[0], "the retry must reuse the original PIN")
            compare(retry.args[1], "MyCustomPass", "the retry must carry the entered pairing password")
        }

        function test_retryIsBlockedWhenCardWasSwapped() {
            launchReadKeycard()

            mockStore.keycardGetMetadataError(pairingErrorText)
            tryVerify(() => !!pairingPasswordInput(), 3000)

            // User swaps the card while the prompt is up. The entered password belongs to the
            // previous card and must not be sent to this one.
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

            // The card rejects it again; the step must come back flagged as incorrect so the
            // user sees the password was wrong rather than a silent no-op.
            mockStore.keycardGetMetadataError(pairingErrorText)
            tryVerify(() => !!findChild(popup, "enterPairingPasswordStep"), 3000)

            const step = findChild(popup, "enterPairingPasswordStep")
            verify(step.wrongPairingPassword,
                   "a repeated pairing error while holding a password means that password was wrong")
        }
    }
}
