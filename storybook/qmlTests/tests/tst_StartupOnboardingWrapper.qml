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
                function setCredential(account, credential) {
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
    }
}
