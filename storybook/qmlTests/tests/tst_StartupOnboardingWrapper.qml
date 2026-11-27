import QtQuick
import QtTest

import StatusQ
import StatusQ.TestHelpers
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Onboarding
import AppLayouts.Onboarding.stores
import AppLayouts.Onboarding.enums

import utils

import Models

Item {
    id: root

    property var pendingCredentialsAtStart: []

    width: 1200
    height: 700

    readonly property string dummyDekHex: "a".repeat(64)
    property var loginModel: accountsModel

    LoginAccountsModel {
        id: accountsModel
    }

    ListModel {
        id: emptyModel
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
                property bool available: true
                property int getStatus: SecureStorage.StatusSuccess
                property var creds: ({})
                property var deleteCalls: []

                function hasCredential(account) {
                    return creds[account] !== undefined ? SecureStorage.StatusSuccess
                                                        : SecureStorage.StatusNotFound
                }
                function getCredential(account) {
                    if (getStatus !== SecureStorage.StatusSuccess)
                        return { status: getStatus, credential: "" }
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
                property int deleteStatus: SecureStorage.StatusSuccess
                function deleteCredential(account) {
                    deleteCalls.push(account)
                    if (deleteStatus !== SecureStorage.StatusSuccess)
                        return deleteStatus
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
                property var loginAccountsModel: root.loginModel

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
                property var loginRequestedCalls: []
                function loginRequested(keyUid, method, data) {
                    loginRequestedCalls.push({ keyUid, method, data })
                }

                property string zeroOnboardedKeyUid: ""
                function canLogIn(keyUid) {
                    return keyUid === zeroOnboardedKeyUid
                            || !!SQUtils.ModelUtils.getByKey(loginAccountsModel, "keyUid", keyUid)
                }
                property bool zeroOnboardingAllowed: false
                property int startZeroOnboardingCalls: 0
                function startZeroOnboarding() {
                    startZeroOnboardingCalls++
                    return ""
                }
                property var deleteMultiaccountCalls: []
                function deleteMultiaccountRequested(keyUid) {
                    deleteMultiaccountCalls.push(keyUid)
                    if (keyUid === zeroOnboardedKeyUid)
                        zeroOnboardedKeyUid = ""
                }
                property var zeroOnboardedCredentialsToRemove: root.pendingCredentialsAtStart.slice()
                function confirmZeroOnboardedCredentialRemoved(keyUid) {
                    zeroOnboardedCredentialsToRemove = zeroOnboardedCredentialsToRemove.filter(k => k !== keyUid)
                }
                property var selectLoginAccountCalls: []
                function selectLoginAccount(keyUid) {
                    selectLoginAccountCalls.push(keyUid)
                }

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

        function init() {
            root.loginModel = accountsModel
        }

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

            // back in place at once, no slide-in transition
            compare(layout.stack.currentItem, layout.stack.loginScreen)
            verify(!layout.stack.busy)

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

        function test_stayLoggedInIndeterminateEnable_data() {
            return [
                { tag: "cleanup verified", deleteStatus: SecureStorage.StatusSuccess,
                    enabled: false, warned: false },
                { tag: "cleanup unverified", deleteStatus: SecureStorage.StatusIndeterminate,
                    enabled: true, warned: true },
            ]
        }

        function test_stayLoggedInIndeterminateEnable(data) {
            wrapper = createTemporaryObject(wrapperComponent, root)
            verify(!!wrapper)
            const unconfirmedSpy = signalSpy.createObject(wrapper, {
                target: wrapper, signalName: "stayLoggedInSaveUnconfirmed" })
            wrapper.secureStorage.setStatus = SecureStorage.StatusIndeterminate
            wrapper.secureStorage.deleteStatus = data.deleteStatus

            wrapper.onboardingStore.stayLoggedInSaveRequested("uid_1", "dek:" + root.dummyDekHex, true)

            compare(wrapper.secureStorage.deleteCalls.length, 1)
            compare(wrapper.onboardingStore.stayLoggedIn, data.enabled)
            compare(unconfirmedSpy.count, data.warned ? 1 : 0)
        }

        function test_selectLoginAccountBindsInitialProfileAndDetachesForNewProfile() {
            wrapper = createTemporaryObject(wrapperComponent, root)
            verify(!!wrapper)
            const layout = findChild(wrapper, "startupOnboardingLayout")
            verify(!!layout)
            const store = wrapper.onboardingStore
            store.selectLoginAccountCalls = []
            const profileSpy = signalSpy.createObject(wrapper, {
                target: wrapper, signalName: "profileSelected" })

            layout.restartFlow()
            tryVerify(() => store.selectLoginAccountCalls.length > 0)
            compare(store.selectLoginAccountCalls[store.selectLoginAccountCalls.length - 1], "uid_1")
            compare(profileSpy.count, 0)

            const loginScreen = layout.stack.loginScreen
            verify(!!loginScreen)
            store.selectLoginAccountCalls = []
            loginScreen.onboardingCreateProfileFlowRequested()
            tryVerify(() => store.selectLoginAccountCalls.length > 0)
            compare(store.selectLoginAccountCalls[store.selectLoginAccountCalls.length - 1], "")
        }

        // Without an opt-in the preference is already ON; next login reconciles
        function test_stayLoggedInIndeterminateFollowStoredKeepsCredential() {
            wrapper = createTemporaryObject(wrapperComponent, root)
            verify(!!wrapper)
            wrapper.onboardingStore.stayLoggedIn = true
            wrapper.secureStorage.setStatus = SecureStorage.StatusIndeterminate

            wrapper.onboardingStore.stayLoggedInSaveRequested("uid_1", "dek:" + root.dummyDekHex, false)

            compare(wrapper.secureStorage.deleteCalls.length, 0)
            compare(wrapper.onboardingStore.stayLoggedIn, true)
        }
    }

    StatusTestCase {
        name: "StartupOnboardingWrapper_zeroOnboarding"
        when: windowShown

        readonly property string zeroKeyUid: "uid_zero"

        function init() {
            root.loginModel = emptyModel
        }

        // A device whose only profile, if any, is the zero-onboarded one (left out of the login list)
        function createWrapper(zeroOnboardedKeyUid, zeroOnboardingAllowed) {
            const wrapper = createTemporaryObject(wrapperComponent, root)
            verify(!!wrapper)
            wrapper.onboardingStore.zeroOnboardedKeyUid = zeroOnboardedKeyUid
            wrapper.onboardingStore.zeroOnboardingAllowed = zeroOnboardingAllowed
            tryCompare(layoutOf(wrapper), "currentPageName", "WelcomePage")
            return wrapper
        }

        function layoutOf(wrapper) {
            return findChild(wrapper, "startupOnboardingLayout")
        }

        function test_createsProfileWhenAllowed() {
            const wrapper = createWrapper("", true)
            wrapper.autoLoginEnabled = true

            compare(wrapper.onboardingStore.startZeroOnboardingCalls, 1)
            tryVerify(() => layoutOf(wrapper).stack.currentItem.objectName === "splashScreenV2")
        }

        function test_noCreationWithoutSecureStorage() {
            const wrapper = createWrapper("", true)
            wrapper.secureStorage.available = false
            wrapper.autoLoginEnabled = true

            compare(wrapper.onboardingStore.startZeroOnboardingCalls, 0)
            compare(layoutOf(wrapper).currentPageName, "WelcomePage")
        }

        // Reachable but refusing writes (Linux locked keyring)
        function test_noCreationWhenStorageRefusesWrites_data() {
            return [
                { tag: "unavailable", status: SecureStorage.StatusUnavailable },
                { tag: "indeterminate", status: SecureStorage.StatusIndeterminate },
            ]
        }
        function test_noCreationWhenStorageRefusesWrites(data) {
            const wrapper = createWrapper("", true)
            wrapper.secureStorage.setStatus = data.status
            wrapper.autoLoginEnabled = true

            compare(wrapper.onboardingStore.startZeroOnboardingCalls, 0)
            compare(layoutOf(wrapper).currentPageName, "WelcomePage")
        }

        function test_writeProbeLeavesNothingStored() {
            const wrapper = createWrapper("", true)
            wrapper.autoLoginEnabled = true

            compare(wrapper.onboardingStore.startZeroOnboardingCalls, 1)
            compare(Object.keys(wrapper.secureStorage.creds).length, 0)
            compare(wrapper.secureStorage.deleteCalls.length, 1)
        }

        function test_noCreationWhenNotAllowed() {
            const wrapper = createWrapper("", false)
            wrapper.autoLoginEnabled = true

            compare(wrapper.onboardingStore.startZeroOnboardingCalls, 0)
        }

        // A failed creation shows Welcome and is not retried in that run
        function test_failedCreationFallsBackToWelcomeOnce() {
            const wrapper = createWrapper("", true)
            wrapper.autoLoginEnabled = true
            wrapper.onboardingStore.accountLoginError("creation failed", false)
            tryCompare(layoutOf(wrapper), "currentPageName", "WelcomePage")

            wrapper.autoLoginEnabled = false
            wrapper.autoLoginEnabled = true
            compare(wrapper.onboardingStore.startZeroOnboardingCalls, 1)
        }

        function notice(wrapper) {
            return findChild(wrapper, "existingProfileUnavailableNotice")
        }

        // The profile exists but could not be opened this run
        function test_unavailableProfileNotice_data() {
            return [
                { tag: "storage unreachable", unreachable: true, unavailable: false, loginFails: false },
                { tag: "storage unavailable", unreachable: false, unavailable: true, loginFails: false },
                { tag: "login failed", unreachable: false, unavailable: false, loginFails: true },
            ]
        }
        function test_unavailableProfileNotice(data) {
            const wrapper = createWrapper(zeroKeyUid, false)
            wrapper.secureStorage.creds[zeroKeyUid] = "dek:" + root.dummyDekHex
            if (data.unreachable)
                wrapper.secureStorage.getStatus = SecureStorage.StatusUnavailable
            if (data.unavailable)
                wrapper.secureStorage.available = false
            wrapper.autoLoginEnabled = true
            if (data.loginFails)
                wrapper.onboardingStore.accountLoginError("file is not a database", false)

            tryCompare(layoutOf(wrapper), "currentPageName", "WelcomePage")
            tryVerify(() => !!notice(wrapper) && notice(wrapper).visible)
            compare(notice(wrapper).text, qsTr("Your existing profile couldn't be opened on this device. Restart the app to try again. Creating a new profile or logging in will delete it."))
        }

        // After "Create / Log in" → Continue the user already knows
        function test_noNoticeAfterSignOut() {
            const wrapper = createWrapper(zeroKeyUid, false)
            wrapper.secureStorage.getStatus = SecureStorage.StatusUnavailable
            verify(!notice(wrapper) || !notice(wrapper).visible)
        }

        function test_noNoticeWithoutZeroOnboardedProfile() {
            const wrapper = createWrapper("", false)
            wrapper.secureStorage.available = false
            wrapper.autoLoginEnabled = true
            verify(!notice(wrapper) || !notice(wrapper).visible)
        }

        function test_removedProfilesCredentialsDeleted() {
            const wrapper = createWrapper("", false)
            wrapper.secureStorage.creds["uid_old"] = "dek:" + root.dummyDekHex
            wrapper.secureStorage.deleteCalls = []
            wrapper.onboardingStore.zeroOnboardedCredentialsToRemove = ["uid_old", "uid_older"]

            compare(wrapper.secureStorage.deleteCalls, ["uid_old", "uid_older"])
            verify(wrapper.secureStorage.creds["uid_old"] === undefined)
            compare(wrapper.onboardingStore.zeroOnboardedCredentialsToRemove, [])
        }

        // The start-up removal runs before the wrapper exists, and the storage arrives later
        function test_credentialsPendingAtStartDeleted() {
            root.pendingCredentialsAtStart = ["uid_old"]
            const wrapper = createWrapper("", false)
            root.pendingCredentialsAtStart = []
            compare(wrapper.onboardingStore.zeroOnboardedCredentialsToRemove, [])

            const storage = wrapper.secureStorage
            wrapper.secureStorage = null
            wrapper.onboardingStore.zeroOnboardedCredentialsToRemove = ["uid_older"]
            compare(wrapper.onboardingStore.zeroOnboardedCredentialsToRemove, ["uid_older"])
            wrapper.secureStorage = storage
            compare(wrapper.onboardingStore.zeroOnboardedCredentialsToRemove, [])
        }

        // NotSupported comes only from the stub backend, which never stored anything
        function test_notSupportedCountsAsRemoved() {
            const wrapper = createWrapper("", false)
            wrapper.secureStorage.deleteStatus = SecureStorage.StatusNotSupported
            wrapper.onboardingStore.zeroOnboardedCredentialsToRemove = ["uid_old"]
            compare(wrapper.onboardingStore.zeroOnboardedCredentialsToRemove, [])
        }

        function test_failedCredentialDeletionStaysPending() {
            const wrapper = createWrapper("", false)
            wrapper.secureStorage.deleteStatus = SecureStorage.StatusUnavailable
            wrapper.onboardingStore.zeroOnboardedCredentialsToRemove = ["uid_old"]
            compare(wrapper.onboardingStore.zeroOnboardedCredentialsToRemove, ["uid_old"])

            wrapper.secureStorage.deleteStatus = SecureStorage.StatusSuccess
            wrapper.secureStorage = wrapper.secureStorage
            wrapper.onboardingStore.zeroOnboardedCredentialsToRemove = ["uid_old"]
            compare(wrapper.onboardingStore.zeroOnboardedCredentialsToRemove, [])
        }

        // Opened although it is not in the login list
        function test_opensZeroOnboardedProfile() {
            const wrapper = createWrapper(zeroKeyUid, false)
            wrapper.secureStorage.creds[zeroKeyUid] = "dek:" + root.dummyDekHex
            wrapper.autoLoginEnabled = true

            const calls = wrapper.onboardingStore.loginRequestedCalls
            compare(calls.length, 1)
            compare(calls[0].keyUid, zeroKeyUid)
            compare(calls[0].data.dek, root.dummyDekHex)
            tryVerify(() => layoutOf(wrapper).stack.currentItem.objectName === "splashScreenV2")
        }

        function test_removesProfileWithUnusableCredential_data() {
            return [
                { tag: "not found", status: SecureStorage.StatusSuccess, credential: undefined },
                { tag: "not supported", status: SecureStorage.StatusNotSupported, credential: undefined },
                { tag: "not a DEK", status: SecureStorage.StatusSuccess, credential: "password" },
            ]
        }

        function test_removesProfileWithUnusableCredential(data) {
            const wrapper = createWrapper(zeroKeyUid, false)
            wrapper.secureStorage.getStatus = data.status
            if (data.credential !== undefined)
                wrapper.secureStorage.creds[zeroKeyUid] = data.credential
            wrapper.autoLoginEnabled = true

            const store = wrapper.onboardingStore
            compare(store.loginRequestedCalls.length, 0)
            compare(store.deleteMultiaccountCalls, [zeroKeyUid])
            verify(wrapper.secureStorage.deleteCalls.indexOf(zeroKeyUid) >= 0)
            compare(layoutOf(wrapper).currentPageName, "WelcomePage")

            // No new zero-onboarded profile in this run
            store.zeroOnboardingAllowed = true
            wrapper.autoLoginEnabled = false
            wrapper.autoLoginEnabled = true
            compare(store.startZeroOnboardingCalls, 0)
        }

        // The store may only be locked or unreachable for now
        function test_keepsProfileWhenStorageUnreachable_data() {
            return [
                { tag: "unavailable", status: SecureStorage.StatusUnavailable },
                { tag: "generic error", status: SecureStorage.StatusGenericError },
            ]
        }

        function test_keepsProfileWhenStorageUnreachable(data) {
            const wrapper = createWrapper(zeroKeyUid, false)
            wrapper.secureStorage.getStatus = data.status
            wrapper.autoLoginEnabled = true

            compare(wrapper.onboardingStore.loginRequestedCalls.length, 0)
            compare(wrapper.onboardingStore.deleteMultiaccountCalls.length, 0)
            compare(wrapper.secureStorage.deleteCalls.length, 0)
            compare(layoutOf(wrapper).currentPageName, "WelcomePage")
        }

        // A wrong key and a corrupted database look the same: never delete on a login error
        function test_loginErrorOfZeroOnboardedProfile_data() {
            return [
                { tag: "wrong key", wrongPassword: true, removed: false },
                { tag: "transient", wrongPassword: false, removed: false },
            ]
        }

        function test_loginErrorOfZeroOnboardedProfile(data) {
            const wrapper = createWrapper(zeroKeyUid, false)
            wrapper.secureStorage.creds[zeroKeyUid] = "dek:" + root.dummyDekHex
            wrapper.autoLoginEnabled = true

            wrapper.onboardingStore.accountLoginError("login failed", data.wrongPassword)

            compare(wrapper.onboardingStore.deleteMultiaccountCalls.length, data.removed ? 1 : 0)
            compare(wrapper.secureStorage.creds[zeroKeyUid] === undefined, data.removed)
            tryCompare(layoutOf(wrapper), "currentPageName", "WelcomePage")
        }
    }

    Component {
        id: signalSpy
        SignalSpy {}
    }
}
