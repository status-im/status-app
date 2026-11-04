import QtQuick
import QtTest

import StatusQ
import StatusQ.TestHelpers

import AppLayouts.Onboarding
import AppLayouts.Onboarding.stores
import AppLayouts.Onboarding.enums

import utils

import Models

Item {
    id: root

    width: 1200
    height: 700

    readonly property string dummyDekHex: "a".repeat(64)

    LoginAccountsModel {
        id: accountsModel
    }

    Component {
        id: wrapperComponent

        StartupOnboardingWrapper {
            anchors.fill: parent

            featureFlagsStore: QtObject {
                readonly property bool keycardEnabled: false
                readonly property bool privacyModeFeatureEnabled: false
            }
            languageStore: QtObject {
                readonly property var availableLanguages: ["en"]
                readonly property string currentLanguage: "en"
                function changeLanguage(code, restart) {}
            }

            keychain: Keychain {
                readonly property bool available: false
                function hasCredential(account) { return Keychain.StatusNotFound }
                function saveCredential(account, credential) { return Keychain.StatusSuccess }
                function deleteCredential(account) { return Keychain.StatusSuccess }
                function requestGetCredential(reason, account) {}
                function cancelActiveRequest() {}
            }

            secureStorage: SecureStorage {
                readonly property bool available: true
                property var creds: ({})
                property var deleteCalls: []

                function hasCredential(account) {
                    return creds[account] !== undefined ? SecureStorage.StatusSuccess
                                                        : SecureStorage.StatusNotFound
                }
                function getCredential(account) {
                    const value = creds[account]
                    return { status: value === undefined ? SecureStorage.StatusNotFound
                                                         : SecureStorage.StatusSuccess,
                             credential: value === undefined ? "" : value }
                }
                property int setStatus: SecureStorage.StatusSuccess
                function setCredential(account, credential) {
                    if (setStatus !== SecureStorage.StatusSuccess)
                        return setStatus
                    creds[account] = credential
                    return SecureStorage.StatusSuccess
                }
                function deleteCredential(account) {
                    deleteCalls.push(account)
                    if (creds[account] === undefined)
                        return SecureStorage.StatusNotFound
                    delete creds[account]
                    return SecureStorage.StatusSuccess
                }
            }

            lastSelectedProfileKeyUid: "uid_1"

            // The storybook stub of OnboardingStore is empty; the API used by the
            // wrapper and layout is declared here (same pattern as tst_OnboardingLayout)
            onboardingStore: OnboardingStore {
                property var loginAccountsModel: accountsModel

                readonly property int keycardState: -1
                readonly property string keycardUID: ""
                readonly property string keycardKeyUID: ""
                readonly property int syncState: 0
                property int keycardRemainingPinAttempts: 5
                property int keycardRemainingPukAttempts: 5
                readonly property bool keycardStatusAvailable: false
                readonly property int keycardAvailableSlots: 0
                readonly property string keycardCardMetadataName: ""
                readonly property string keycardCardMetadataWalletAccountsJson: ""
                readonly property int convertKeycardAccountState: 0
                readonly property bool convertKeycardAccountRestartRequired: false

                function getPasswordStrengthScore(password) { return 4 }
                function isProfileMigratedToDEKEncryption(keyUid) { return true }
                function validMnemonic(mnemonic) { return true }
                function isMnemonicDuplicate(mnemonic) { return false }
                function validateLocalPairingConnectionString(connectionString) { return false }
                function inputConnectionStringForBootstrapping(connectionString) {}
                function finishOnboardingFlow(flow, data) { return "" }
                function loginRequested(keyUid, method, data) {}

                signal accountLoginError(string error, bool wrongPassword)
                signal stayLoggedInSaveRequested(string keyUid, string credential, bool enablePreference)
                signal stayLoggedInDeleteRequested(string keyUid)

                // Settings wrappers the real store exposes (store-layer rule)
                property bool stayLoggedIn: false
                property var suppressionCalls: []
                function setStayLoggedIn(value) { stayLoggedIn = value }
                function setAutoLoginSuppressed(keyUid, value) {
                    suppressionCalls.push({ keyUid, value })
                    return true
                }
            }
        }
    }

    StatusTestCase {
        name: "StartupOnboardingWrapper_autoLoginFallback"
        when: windowShown

        property var wrapper: null

        function cleanup() {
            wrapper = null
        }

        // A failed silent auto-login must delete the ATTEMPTED profile's credential
        // exactly once, through the wrapper's real error handler; a later manual-login
        // error while ANOTHER profile is selected must not touch that profile's
        // credential.
        function test_autoLoginFailureDeletesOnlyTheAttemptedProfile() {
            wrapper = createTemporaryObject(wrapperComponent, root)
            verify(!!wrapper)

            const layout = findChild(wrapper, "startupOnboardingLayout")
            verify(!!layout)

            wrapper.secureStorage.creds["uid_1"] = "dek:" + root.dummyDekHex
            wrapper.secureStorage.creds["uid_2"] = "dek:" + root.dummyDekHex

            wrapper.autoLoginEnabled = true // triggers the one-shot attempt (profile A)
            tryVerify(() => layout.autoLoginAttempted)

            // First login error: the auto-login failed — A's credential is deleted,
            // exactly once, using the RECORDED key UID
            wrapper.onboardingStore.accountLoginError("stale dek", false)
            compare(wrapper.secureStorage.deleteCalls.length, 1)
            compare(wrapper.secureStorage.deleteCalls[0], "uid_1")
            compare(wrapper.secureStorage.creds["uid_1"], undefined)

            // The user switches to profile B; a manual login fails. Were the handler
            // still keyed on the mutable current selection, B's valid credential would
            // be deleted here.
            wrapper.lastSelectedProfileKeyUid = "uid_2"
            wrapper.onboardingStore.accountLoginError("wrong password", false)

            compare(wrapper.secureStorage.deleteCalls.length, 1)
            compare(wrapper.secureStorage.creds["uid_2"], "dek:" + root.dummyDekHex)
        }

        // Lifecycle cleanup (keycard conversion): the store's delete request removes
        // the silent credential through the wrapper's real handler.
        function test_stayLoggedInDeleteRequestRemovesCredential() {
            wrapper = createTemporaryObject(wrapperComponent, root)
            verify(!!wrapper)

            wrapper.secureStorage.creds["uid_1"] = "dek:" + root.dummyDekHex
            wrapper.onboardingStore.stayLoggedIn = true
            wrapper.onboardingStore.stayLoggedInDeleteRequested("uid_1")

            compare(wrapper.secureStorage.creds["uid_1"], undefined)
            compare(wrapper.secureStorage.deleteCalls.length, 1)
            compare(wrapper.secureStorage.deleteCalls[0], "uid_1")
            compare(wrapper.onboardingStore.stayLoggedIn, false) // verified deletion -> pref off
        }

        // Onboarding opt-in: the preference becomes stored only on a VERIFIED credential
        // write — an unverified write (e.g. locked keyring) must not leave the toggle ON
        // with nothing stored. Every explicit login lifts the auto-login suppression.
        function test_stayLoggedInSavePreferenceRequiresVerifiedWrite() {
            wrapper = createTemporaryObject(wrapperComponent, root)
            verify(!!wrapper)
            const store = wrapper.onboardingStore

            wrapper.secureStorage.setStatus = SecureStorage.StatusUnavailable
            store.stayLoggedInSaveRequested("uid_1", "dek:" + root.dummyDekHex, true)
            compare(store.stayLoggedIn, false)
            compare(store.suppressionCalls.length, 1)
            compare(store.suppressionCalls[0].keyUid, "uid_1")
            compare(store.suppressionCalls[0].value, false)

            wrapper.secureStorage.setStatus = SecureStorage.StatusSuccess
            store.stayLoggedInSaveRequested("uid_1", "dek:" + root.dummyDekHex, true)
            compare(store.stayLoggedIn, true)
            compare(wrapper.secureStorage.creds["uid_1"], "dek:" + root.dummyDekHex)
        }

        // A failed MANUAL login must keep showing the error on the login screen
        // (red border + "Password incorrect") — the wrapper's splash cleanup must not
        // recreate the screen and lose the error state the layout just set (#23055).
        function test_manualLoginErrorStaysVisibleOnTheLoginScreen() {
            wrapper = createTemporaryObject(wrapperComponent, root)
            verify(!!wrapper)

            const layout = findChild(wrapper, "startupOnboardingLayout")
            verify(!!layout)
            layout.restartFlow()
            tryVerify(() => !!layout.stack.currentItem)

            const userSelector = findChild(layout.stack.currentItem, "loginUserSelector")
            verify(!!userSelector)
            userSelector.setSelection("uid_1")

            // Manual login via the LAYOUT's signal — the wrapper reacts by pushing the
            // splash screen above the login screen (the production sequence)
            layout.loginRequested("uid_1", Onboarding.LoginMethod.Password, { password: "wrong" })
            tryVerify(() => layout.stack.currentItem !== layout.stack.loginScreen,
                      2000, "the splash must be pushed above the login screen")

            wrapper.onboardingStore.accountLoginError("login failed", true)

            // Back on a login screen that SHOWS the error (red border via validationError)
            tryVerify(() => {
                const screen = layout.stack.loginScreen
                if (!screen)
                    return false
                const passwordBox = findChild(screen, "passwordBox")
                return !!passwordBox && passwordBox.validationError.indexOf("Password incorrect") >= 0
            }, 2000, "login screen must display the manual-login error")
        }

        // Even with the preference ON — e.g. a keycard profile converted while the
        // preference survived — an empty-credential request is reconciliation-only:
        // never store an empty string, remove any leftover credential.
        function test_stayLoggedInSaveEmptyNeverStores() {
            wrapper = createTemporaryObject(wrapperComponent, root)
            verify(!!wrapper)
            wrapper.onboardingStore.stayLoggedIn = true
            wrapper.secureStorage.creds["uid_1"] = "dek:" + root.dummyDekHex

            wrapper.onboardingStore.stayLoggedInSaveRequested("uid_1", "", false)

            compare(wrapper.secureStorage.creds["uid_1"], undefined)
        }

        // Preference OFF: the task sends an empty credential (no DEK export) and any
        // stale stored credential is reconciled away.
        function test_stayLoggedInSavePrefOffReconcilesStaleCredential() {
            wrapper = createTemporaryObject(wrapperComponent, root)
            verify(!!wrapper)

            wrapper.secureStorage.creds["uid_1"] = "dek:" + root.dummyDekHex
            wrapper.onboardingStore.stayLoggedInSaveRequested("uid_1", "", false)

            compare(wrapper.secureStorage.creds["uid_1"], undefined)
            compare(wrapper.onboardingStore.stayLoggedIn, false)
        }
    }
}
