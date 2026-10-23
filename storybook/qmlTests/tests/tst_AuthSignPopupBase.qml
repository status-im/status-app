import QtQuick
import QtQuick.Controls

import QtTest

import StatusQ

import shared.popups.auth_sign_base 1.0
import utils

Item {
    id: root

    width: 480
    height: 520

    Component {
        id: componentUnderTest

        PopupBase {
            reason: "testing"
            keyUid: "key-uid-1"

            keychain: Keychain {}

            keycardState: Constants.keycard.state.ready
            keycardUid: "keycard-uid-1"
            remainingPinAttempts: 3
            userProfileKeyUid: "key-uid-1"
            userProfilePublicKey: "0xpub"
            userProfileMigratedToColdWallet: true
            isKeycardKeyPair: true

            btnActionName: "Authenticate"
            btnPasswordActionAndUpdateName: "Update password & authenticate"
            btnPinActionAndUpdateName: "Update PIN & authenticate"

            closePolicy: Popup.NoAutoClose
        }
    }

    Component {
        id: mockedKeychainComponent

        // Shadows the C++ members so no real OS keychain/biometrics is touched
        Keychain {
            property int requestCount: 0
            property var updatedCredentials: []
            readonly property bool available: true
            function hasCredential(account) {
                return account === "key-uid-1" ? Keychain.StatusSuccess
                                               : Keychain.StatusNotFound
            }
            function requestGetCredential(reason, account) {
                requestCount++
                return Keychain.StatusSuccess
            }
            function updateCredential(account, credential) {
                updatedCredentials.push({ account, credential })
                return Keychain.StatusSuccess
            }
        }
    }

    Component {
        id: mockedSecureStorageComponent

        // Shadows the C++ members so no real OS secure storage is touched
        SecureStorage {
            readonly property bool available: true
            property var creds: ({})
            property var setCalls: []

            function hasCredential(account) {
                return creds[account] !== undefined ? SecureStorage.StatusSuccess
                                                    : SecureStorage.StatusNotFound
            }
            function setCredential(account, credential) {
                setCalls.push({ account, credential })
                creds[account] = credential
                return SecureStorage.StatusSuccess
            }
            function deleteCredential(account) {
                delete creds[account]
                return SecureStorage.StatusSuccess
            }
            function getCredential(account) {
                const value = creds[account]
                return { status: value === undefined ? SecureStorage.StatusNotFound
                                                     : SecureStorage.StatusSuccess,
                         credential: value === undefined ? "" : value }
            }
        }
    }

    TestCase {
        name: "AuthSignPopupBase_passwordFocus"
        when: windowShown

        property var popup: null
        property var mockKeychain: null

        function init() {
            mockKeychain = createTemporaryObject(mockedKeychainComponent, root)
            verify(!!mockKeychain)
        }

        function cleanup() {
            if (popup) {
                popup.destroy()
                popup = null
            }
        }

        function createSoftwareWalletPopup(keyUid, performPasswordAction) {
            popup = createTemporaryObject(componentUnderTest, root, {
                                              keychain: mockKeychain,
                                              keyUid: keyUid,
                                              userProfileKeyUid: keyUid,
                                              userProfileMigratedToColdWallet: false,
                                              isKeycardKeyPair: false,
                                              performPasswordAction: performPasswordAction
            })
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)
        }

        function test_passwordOnlyFocusesInput() {
            createSoftwareWalletPopup("key-without-biometrics", password => true)

            tryVerify(() => !!findChild(popup, "authenticationPasswordInput"))
            const passwordInput = findChild(popup, "authenticationPasswordInput")
            tryCompare(passwordInput, "activeFocus", true)
        }

        // biometricsAllowed: false must take manual-entry-only effect even with a
        // stored credential: no biometric auto-start (no OS prompt), no "Use
        // biometrics" button, password input focused right away. Used by actions that
        // exist to prove the user still KNOWS the credential (disabling biometrics).
        function test_biometricsNotOfferedWhenDisallowed() {
            popup = createTemporaryObject(componentUnderTest, root, {
                                              keychain: mockKeychain,
                                              keyUid: "key-uid-1", // has a stored credential
                                              userProfileKeyUid: "key-uid-1",
                                              userProfileMigratedToColdWallet: false,
                                              isKeycardKeyPair: false,
                                              biometricsAllowed: false,
                                              performPasswordAction: password => true
            })
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)

            tryVerify(() => !!findChild(popup, "authenticationPasswordInput"))
            const passwordInput = findChild(popup, "authenticationPasswordInput")
            tryCompare(passwordInput, "activeFocus", true)

            compare(mockKeychain.requestCount, 0) // biometrics never started
            const bioButton = findChild(popup, "useBiometricsButton")
            verify(!bioButton || !bioButton.visible)
        }

        function test_biometricSuccessDoesNotFocusInput() {
            let providedPassword = ""
            createSoftwareWalletPopup("key-uid-1", password => {
                                          providedPassword = password
                                          return true
                                      })

            tryCompare(mockKeychain, "requestCount", 1)
            mockKeychain.getCredentialRequestCompleted(Keychain.StatusSuccess, "secret")

            compare(providedPassword, "secret")
            tryVerify(() => !!findChild(popup, "authenticationPasswordInput"))
            const passwordInput = findChild(popup, "authenticationPasswordInput")
            verify(!!passwordInput)
            compare(passwordInput.activeFocus, false)
        }

        function test_biometricCredentialMismatchFocusesInput() {
            createSoftwareWalletPopup("key-uid-1", password => false)

            tryCompare(mockKeychain, "requestCount", 1)
            mockKeychain.getCredentialRequestCompleted(Keychain.StatusSuccess, "stale-secret")

            tryVerify(() => !!findChild(popup, "authenticationPasswordInput"))
            const passwordInput = findChild(popup, "authenticationPasswordInput")
            tryCompare(passwordInput, "activeFocus", true)
        }
    }

    TestCase {
        name: "AuthSignPopupBase_biometricsAutoStart"
        when: windowShown

        property var popup: null
        property var mockKeychain: null

        function init() {
            mockKeychain = createTemporaryObject(mockedKeychainComponent, root)
            verify(!!mockKeychain)
        }

        function cleanup() {
            if (popup) {
                popup.destroy()
                popup = null
            }
        }

        function test_autoStartsForProfileKeycardKeyPair() {
            popup = createTemporaryObject(componentUnderTest, root, { keychain: mockKeychain })
            verify(!!popup)
            popup.open()

            tryCompare(mockKeychain, "requestCount", 1)
        }

        // SignPopup's externalAuthorization can only settle to its final value after the store
        // gets ready — the gate turning on late must still auto-start biometrics.
        function test_autoStartsWhenGateTurnsOnLate() {
            popup = createTemporaryObject(componentUnderTest, root, {
                                              keychain: mockKeychain,
                                              externalAuthorization: true
                                          })
            verify(!!popup)
            popup.open()

            waitForRendering(popup.contentItem)
            compare(mockKeychain.requestCount, 0)

            popup.externalAuthorization = false
            tryCompare(mockKeychain, "requestCount", 1)
        }

        // Biometrics holds the profile credential only: signing with a non-profile keycard
        // keypair must go through its own keycard, never through biometrics.
        function test_neverStartsForNonProfileKeycardKeyPair() {
            popup = createTemporaryObject(componentUnderTest, root, {
                                              keychain: mockKeychain,
                                              keyUid: "other-keypair-uid",
                                              externalAuthorization: true
                                          })
            verify(!!popup)
            popup.open()

            waitForRendering(popup.contentItem)

            // mimic the store-ready flip that re-resolves externalAuthorization for keycard keypairs
            popup.externalAuthorization = false
            waitForRendering(popup.contentItem)

            compare(mockKeychain.requestCount, 0)

            const bioButton = findChild(popup, "useBiometricsButton")
            verify(!!bioButton)
            verify(!bioButton.visible)
        }
    }

    TestCase {
        name: "AuthSignPopupBase_dekCredential"
        when: windowShown

        property var popup: null
        property var mockKeychain: null

        function init() {
            mockKeychain = createTemporaryObject(mockedKeychainComponent, root)
            verify(!!mockKeychain)
        }

        function cleanup() {
            if (popup) {
                popup.destroy()
                popup = null
            }
        }

        function createPasswordPopup(extraProperties) {
            const properties = Object.assign({
                                                 keychain: mockKeychain,
                                                 isKeycardKeyPair: false,
                                                 userProfileMigratedToColdWallet: false
                                             }, extraProperties || {})
            const created = createTemporaryObject(componentUnderTest, root, properties)
            verify(!!created)
            return created
        }

        // A dek-tagged biometric secret is stripped and used on the password rails;
        // the stored item is already current, so no keychain update happens.
        function test_dekSecretIsStrippedAndUsedAsPassword() {
            let capturedPassword = ""
            popup = createPasswordPopup()
            popup.performPasswordAction = (password) => {
                capturedPassword = password
                return true
            }
            popup.open()
            tryCompare(popup, "opened", true)
            tryCompare(mockKeychain, "requestCount", 1)

            mockKeychain.getCredentialRequestCompleted(Keychain.StatusSuccess, "dek:aabbcc001122")

            tryCompare(popup, "lastUsedPin", "") // password path, not keycard
            compare(capturedPassword, "aabbcc001122")
            compare(mockKeychain.updatedCredentials.length, 0)
        }

        // A legacy (untagged) biometric secret that authenticates successfully is refreshed
        // in the keychain through the injected transform (upgrade to the wrapped DEK).
        function test_legacySecretUpgradesStoredCredential() {
            let capturedPassword = ""
            popup = createPasswordPopup({
                                            getCredentialForStorage: (keyUid, password) => "dek:transformed-" + password
                                        })
            popup.performPasswordAction = (password) => {
                capturedPassword = password
                return true
            }
            popup.open()
            tryCompare(popup, "opened", true)
            tryCompare(mockKeychain, "requestCount", 1)

            mockKeychain.getCredentialRequestCompleted(Keychain.StatusSuccess, "legacy-password")

            compare(capturedPassword, "legacy-password")
            tryCompare(mockKeychain.updatedCredentials, "length", 1)
            compare(mockKeychain.updatedCredentials[0].account, "key-uid-1")
            compare(mockKeychain.updatedCredentials[0].credential, "dek:transformed-legacy-password")
        }

        // Flows that transfer the password itself (device syncing) or that prove the
        // user still knows it (disabling biometrics) never offer biometrics at all:
        // no biometric request is started and the action only runs on typed input.
        function test_biometricsDisallowedNeverStartsBiometrics() {
            let actionRuns = 0
            popup = createPasswordPopup({ biometricsAllowed: false })
            popup.performPasswordAction = (password) => {
                actionRuns++
                return true
            }
            popup.open()
            tryCompare(popup, "opened", true)

            waitForRendering(popup.contentItem)
            compare(mockKeychain.requestCount, 0) // biometrics never started
            compare(actionRuns, 0)
            verify(popup.opened) // waits for manual entry
        }
    }

    TestCase {
        name: "AuthSignPopupBase_secureStorageRepair"
        when: windowShown

        property var popup: null
        property var mockKeychain: null
        property var mockSecureStorage: null

        function init() {
            mockKeychain = createTemporaryObject(mockedKeychainComponent, root)
            verify(!!mockKeychain)
            mockSecureStorage = createTemporaryObject(mockedSecureStorageComponent, root)
            verify(!!mockSecureStorage)
            // The repair only applies when a silent credential is already stored
            mockSecureStorage.creds["key-uid-1"] = "dek:stale-stored-dek"
        }

        function cleanup() {
            if (popup) {
                popup.destroy()
                popup = null
            }
        }

        function createRepairPopup(extraProperties) {
            const properties = Object.assign({
                                                 keychain: mockKeychain,
                                                 secureStorage: mockSecureStorage,
                                                 isKeycardKeyPair: false,
                                                 userProfileMigratedToColdWallet: false,
                                                 // biometric-storage conversion — its result must NEVER
                                                 // reach the silent store
                                                 getCredentialForStorage: (keyUid, password) => "dek:biometric-" + password
                                             }, extraProperties || {})
            const created = createTemporaryObject(componentUnderTest, root, properties)
            verify(!!created)
            return created
        }

        // Runs the legacy-secret upgrade flow (the trigger the repair rides on).
        function runLegacyUpgradeFlow(secret) {
            popup.performPasswordAction = (password) => true
            popup.open()
            tryCompare(popup, "opened", true)
            tryCompare(mockKeychain, "requestCount", 1)
            mockKeychain.getCredentialRequestCompleted(Keychain.StatusSuccess, secret)
        }

        // The strict DEK-only conversion rejects (legacy profile): nothing may reach the
        // silent store. This includes DEK-shaped legacy passwords — the converter ignores
        // shape, and the popup never falls back to the biometric value.
        function test_repairSkipsWhenStrictConversionRejects() {
            popup = createRepairPopup({
                                          getStayLoggedInCredentialForStorage: (keyUid, credential) => ""
                                      })
            runLegacyUpgradeFlow("legacy-password")

            tryCompare(mockKeychain.updatedCredentials, "length", 1) // biometric refresh ran
            compare(mockSecureStorage.setCalls.length, 0)            // silent store untouched
            compare(mockSecureStorage.creds["key-uid-1"], "dek:stale-stored-dek")
        }

        // The strict conversion succeeds: exactly one silent-store write with that result.
        function test_repairStoresStrictConversionResult() {
            popup = createRepairPopup({
                                          getStayLoggedInCredentialForStorage: (keyUid, credential) => "dek:strict-" + credential
                                      })
            runLegacyUpgradeFlow("legacy-password")

            tryCompare(mockSecureStorage.setCalls, "length", 1)
            compare(mockSecureStorage.setCalls[0].account, "key-uid-1")
            compare(mockSecureStorage.setCalls[0].credential, "dek:strict-legacy-password")
        }

        // Even when both converters return dek-tagged values, the silent store receives
        // ONLY the strict converter's result — never the biometric one.
        function test_repairNeverReusesBiometricResult() {
            popup = createRepairPopup({
                                          getStayLoggedInCredentialForStorage: (keyUid, credential) => "dek:strict-independent"
                                      })
            runLegacyUpgradeFlow("legacy-password")

            tryCompare(mockKeychain.updatedCredentials, "length", 1)
            compare(mockKeychain.updatedCredentials[0].credential, "dek:biometric-legacy-password")
            tryCompare(mockSecureStorage.setCalls, "length", 1)
            compare(mockSecureStorage.setCalls[0].credential, "dek:strict-independent")
            verify(mockSecureStorage.setCalls[0].credential !== mockKeychain.updatedCredentials[0].credential)
        }

        // The exact original regression vector: a RAW legacy password that is DEK-shaped
        // ("dek:legacy-password"), submitted manually after a biometric mismatch. The
        // strict converter rejects it (legacy profile); a future shortcut keying on
        // credential.startsWith("dek:") would wrongly store it and fail this test.
        function test_repairRejectsDekShapedLegacyPasswordAfterMismatch() {
            popup = createRepairPopup({
                                          getStayLoggedInCredentialForStorage: (keyUid, credential) => ""
                                      })
            let capturedPasswords = []
            popup.performPasswordAction = (password) => {
                capturedPasswords.push(password)
                return password === "dek:legacy-password"
            }
            popup.open()
            tryCompare(popup, "opened", true)
            tryCompare(mockKeychain, "requestCount", 1)

            // Biometrics produce a stale legacy secret -> action fails -> mismatch
            mockKeychain.getCredentialRequestCompleted(Keychain.StatusSuccess, "stale-secret")

            // The user types the working, DEK-shaped raw password and submits manually
            const input = findChild(popup, "authenticationPasswordInput")
            verify(!!input)
            input.text = "dek:legacy-password" // editing also clears the wrong-password flag

            const submitButton = findChild(popup, "keycardPopupBaseSubmitButton")
            verify(!!submitButton)
            tryVerify(() => submitButton.visible && submitButton.enabled)
            submitButton.clicked() // deterministic, geometry-independent submission

            // The manual submission actually carried the DEK-shaped raw password
            compare(capturedPasswords.length, 2) // biometric attempt + manual submission
            compare(capturedPasswords[0], "stale-secret")
            compare(capturedPasswords[1], "dek:legacy-password")

            // The mismatch repair ran: the biometric item was refreshed through its own
            // converter, but the silent store was NOT touched — the DEK-shaped raw
            // password was rejected by the strict converter, not waved through by shape.
            tryCompare(mockKeychain.updatedCredentials, "length", 1)
            compare(mockKeychain.updatedCredentials[0].credential, "dek:biometric-dek:legacy-password")
            compare(mockSecureStorage.setCalls.length, 0)
            compare(mockSecureStorage.creds["key-uid-1"], "dek:stale-stored-dek")
        }
    }

    TestCase {
        name: "AuthSignPopupBase_keycardPin"
        when: windowShown

        property var popup: null

        function cleanup() {
            if (popup) {
                popup.destroy()
                popup = null
            }
        }

        // The PIN used for the keycard action must be exposed via lastUsedPin, so that
        // concrete popups (AuthenticationPopup) can propagate it on success and the
        // enable-biometrics handlers store the PIN (not the encryption public key).
        function test_lastUsedPinExposesEnteredPin() {
            let capturedKeyUid = ""
            let capturedPin = ""

            popup = createTemporaryObject(componentUnderTest, root)
            verify(!!popup)
            popup.performKeycardAction = (keyUid, pin, pairingPassword) => {
                capturedKeyUid = keyUid
                capturedPin = pin
            }
            popup.open()

            compare(popup.lastUsedPin, "")

            tryVerify(() => !!findChild(popup, "keycardAuthPinInput"))
            const pinInput = findChild(popup, "keycardAuthPinInput")
            pinInput.setPin("123456") // completing the PIN auto-submits the keycard action

            compare(capturedKeyUid, "key-uid-1")
            compare(capturedPin, "123456")
            compare(popup.lastUsedPin, "123456")

            popup.handleKeycardSuccess()
            compare(popup.lastUsedPin, "123456")
        }
    }

    TestCase {
        name: "AuthSignPopupBase_untrustedKeycard"
        when: windowShown

        property var popup: null

        function cleanup() {
            if (popup) {
                popup.destroy()
                popup = null
            }
        }

        function test_untrustedKeycardErrorShowsKeycardAuth_data() {
            return [
                {tag: "library error", error: "Keycard authentication failed: secure channel not signed by the card's identity key"},
                {tag: "state error", error: "Card not ready (state: untrusted-keycard)"},
            ]
        }

        function test_untrustedKeycardErrorShowsKeycardAuth(data) {
            popup = createTemporaryObject(componentUnderTest, root, {
                                              keycardState: Constants.keycard.state.untrustedKeycard
                                          })
            verify(!!popup)
            popup.open()
            tryCompare(popup, "opened", true)

            popup.handleKeycardError(data.error)

            tryVerify(() => !!findChild(popup, "keycardAuthTitle"), 3000,
                      "an untrusted card must show the Keycard error, not the PIN input")
            compare(findChild(popup, "keycardAuthTitle").text, "Keycard not verified")
        }
    }
}
