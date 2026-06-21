import QtCore
import QtQuick
import QtTest

import StatusQ // ClipboardUtils
import StatusQ.Core.Theme
import StatusQ.TestHelpers

import AppLayouts.Onboarding
import AppLayouts.Onboarding.pages
import AppLayouts.Onboarding.stores
import AppLayouts.Onboarding.enums

import shared.stores as SharedStores

import utils

import Models

Item {
    id: root

    width: 1200
    height: 700

    QtObject {
        id: mockDriver
        property int keycardState // enum Onboarding.KeycardState
        property bool biometricsAvailable
        property string existingPin

        readonly property string mnemonic: "apple banana cat country catalog catch category cattle dog elephant fish grape"
        readonly property string dummyNewPassword: "0123456789"
    }

    LoginAccountsModel {
        id: loginAccountsModel
    }

    ListModel {
        id: emptyModel
    }

    Component {
        id: componentUnderTest

        OnboardingLayout {
            anchors.fill: parent

            networkChecksEnabled: false
            keycardPinInfoPageDelay: 0

            availableLanguages: ["de", "cs", "en", "en_CA", "ko", "ar", "fr", "fr_CA", "pt_BR", "pt", "uk", "ja", "el"]
            currentLanguage: "en"

            keychain: Keychain {
                readonly property bool available: mockDriver.biometricsAvailable
                function hasCredential(account) {
                    return mockDriver.biometricsAvailable ? Keychain.StatusSuccess
                                                          : Keychain.StatusNotFound
                }
            }

            onboardingStore: OnboardingStore {
                readonly property int keycardState: mockDriver.keycardState // enum Onboarding.KeycardState
                readonly property string keycardUID: "kc_uid_4"
                readonly property string keycardKeyUID: "uid_4"
                property int keycardRemainingPinAttempts: Constants.onboarding.defaultPinAttempts
                property int keycardRemainingPukAttempts: Constants.onboarding.defaultPukAttempts
                property var loginAccountsModel: emptyModel

                // password
                function getPasswordStrengthScore(password: string) {
                    return Math.min(password.length-1, 4)
                }

                function finishOnboardingFlow(flow: int, data: Object) { // -> bool
                    return true
                }

                // seedphrase/mnemonic
                function validMnemonic(mnemonic: string) { // -> bool
                    return mnemonic === mockDriver.mnemonic
                }

                function isMnemonicDuplicate(mnemonic: string) { // -> bool
                    return false
                }

                readonly property int syncState: Onboarding.ProgressState.InProgress // enum Onboarding.ProgressState
                function validateLocalPairingConnectionString(connectionString: string) {
                    return !Number.isNaN(parseInt(connectionString))
                }
                function inputConnectionStringForBootstrapping(connectionString: string) {}

                // password signals
                signal accountLoginError(string error, bool wrongPassword)
            }

            onLoginRequested: (keyUid, method, data) => {
                // SIMULATION: emit an error in case of wrong password/PIN
                if ((method === Onboarding.LoginMethod.Password && data.password !== mockDriver.dummyNewPassword) ||
                    (method === Onboarding.LoginMethod.Keycard && data.pin !== mockDriver.existingPin) ){
                    onboardingStore.accountLoginError("", true)
                }
            }

            privacyModeFeatureEnabled: false
        }
    }

    SignalSpy {
        id: dynamicSpy

        function setup(t, s) {
            clear()
            target = t
            signalName = s
        }

        function cleanup() {
            target = null
            signalName = ""
            clear()
        }
    }

    SignalSpy {
        id: finishedSpy
        target: controlUnderTest
        signalName: "finished"
    }

    SignalSpy {
        id: loginSpy
        target: controlUnderTest
        signalName: "loginRequested"
    }

    property OnboardingLayout controlUnderTest: null

    StatusTestCase {
        name: "OnboardingLayout"

        function disableTransitions(stack) {
            stack.pushEnter = null
            stack.pushExit = null
            stack.popEnter = null
            stack.popExit = null
            stack.replaceEnter = null
            stack.replaceExit = null
        }

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)

            // disable animated transitions to speed-up tests
            const stack = controlUnderTest.stack

            disableTransitions(stack)
            stack.topLevelStackChanged.connect(() => {
                disableTransitions(stack.topLevelStack)
            })
        }

        function cleanup() {
            mockDriver.keycardState = -1
            mockDriver.biometricsAvailable = false
            mockDriver.existingPin = ""
            dynamicSpy.cleanup()
            finishedSpy.clear()
            loginSpy.clear()
        }

        function getCurrentPage(stack, pageClass) {
            if (!stack || !pageClass)
                fail("getCurrentPage: expected param 'stack' or 'pageClass' empty")
            verify(!!stack)
            tryCompare(stack, "topLevelStackBusy", false) // wait for page transitions to stop

            if (stack.topLevelItem instanceof Loader) {
                verify(stack.topLevelItem.item instanceof pageClass)
                return stack.topLevelItem.item
            }

            verify(stack.topLevelItem instanceof pageClass)
            return stack.topLevelItem
        }

        // common variant data for all flow related TDD tests
        function init_data() {
            return [ { tag: "bioEnabled", biometrics: true, bioEnabled: true },
                   { tag: "bioDisabled", biometrics: true, bioEnabled: false },
                   { tag: "noBiometrics", biometrics: false },
                    ]
        }

        function test_basicGeometry() {
            verify(!!controlUnderTest)
            verify(controlUnderTest.width > 0)
            verify(controlUnderTest.height > 0)
        }

        // FLOW: Create Profile -> Start fresh (create profile with new password)
        function test_flow_createProfile_withPassword(data) {
            verify(!!controlUnderTest)
            mockDriver.biometricsAvailable = data.biometrics

            const stack = controlUnderTest.stack
            verify(!!stack)

            // PAGE 1: Welcome
            let page = getCurrentPage(stack, WelcomePage)
            waitForRendering(page)

            const btnCreateProfile = findChild(controlUnderTest, "btnCreateProfile")
            verify(!!btnCreateProfile)
            mouseClick(btnCreateProfile)

            // PAGE 2: Create profile
            page = getCurrentPage(stack, CreateProfilePage)

            const btnCreateWithPassword = findChild(controlUnderTest, "btnCreateWithPassword")
            verify(!!btnCreateWithPassword)
            mouseClick(btnCreateWithPassword)

            // PAGE 3: Create password
            page = getCurrentPage(stack, CreatePasswordPage)

            let infoButton = findChild(controlUnderTest, "infoButton")
            verify(!!infoButton)
            mouseClick(infoButton)
            const passwordDetailsPopup = findChild(controlUnderTest, "passwordDetailsPopup")
            verify(!!passwordDetailsPopup)
            tryVerify(() => passwordDetailsPopup.opened)
            keyClick(Qt.Key_Escape) // close the popup
            tryVerify( () => passwordDetailsPopup.exit ? !passwordDetailsPopup.exit.running : true)

            const btnConfirmPassword = findChild(controlUnderTest, "btnConfirmPassword")
            verify(!!btnConfirmPassword)
            compare(btnConfirmPassword.enabled, false)

            const passwordViewNewPassword = findChild(controlUnderTest, "passwordViewNewPassword")
            verify(!!passwordViewNewPassword)
            mouseClick(passwordViewNewPassword)
            compare(passwordViewNewPassword.activeFocus, true)
            compare(passwordViewNewPassword.text, "")

            keyClickSequence(mockDriver.dummyNewPassword)
            compare(passwordViewNewPassword.text, mockDriver.dummyNewPassword)
            compare(btnConfirmPassword.enabled, false)

            const passwordViewNewPasswordConfirm = findChild(controlUnderTest, "passwordViewNewPasswordConfirm")
            verify(!!passwordViewNewPasswordConfirm)
            mouseClick(passwordViewNewPasswordConfirm)
            compare(passwordViewNewPasswordConfirm.activeFocus, true)
            compare(passwordViewNewPasswordConfirm.text, "")

            keyClickSequence(mockDriver.dummyNewPassword)
            compare(passwordViewNewPassword.text, mockDriver.dummyNewPassword)
            compare(btnConfirmPassword.enabled, true)

            mouseClick(btnConfirmPassword)

            // PAGE 4: Enable Biometrics
            if (data.biometrics) {
                page = getCurrentPage(stack, EnableBiometricsPage)

                const enableBioButton = findChild(controlUnderTest, data.bioEnabled ? "btnEnableBiometrics" : "btnDontEnableBiometrics")
                dynamicSpy.setup(page, "enableBiometricsRequested")
                mouseClick(enableBioButton)
                tryCompare(dynamicSpy, "count", 1)
                compare(dynamicSpy.signalArguments[0][0], data.bioEnabled)
            }

            // FINISH
            tryCompare(finishedSpy, "count", 1)
            compare(finishedSpy.signalArguments[0][0], Onboarding.OnboardingFlow.CreateProfileWithPassword)
            const resultData = finishedSpy.signalArguments[0][1]
            verify(!!resultData)
            compare(resultData.password, mockDriver.dummyNewPassword)
            compare(resultData.enableBiometrics, data.biometrics && data.bioEnabled)
            compare(resultData.keycardPin, "")
            compare(resultData.seedphrase, "")
        }


        // FLOW: Create Profile -> Use a recovery phrase (create profile with seedphrase)
        function test_flow_createProfile_withSeedphrase(data) {
            verify(!!controlUnderTest)
            mockDriver.biometricsAvailable = data.biometrics

            const stack = controlUnderTest.stack
            verify(!!stack)

            // PAGE 1: Welcome
            let page = getCurrentPage(stack, WelcomePage)
            waitForRendering(page)

            const btnCreateProfile = findChild(controlUnderTest, "btnCreateProfile")
            verify(!!btnCreateProfile)
            mouseClick(btnCreateProfile)

            // PAGE 2: Create profile
            page = getCurrentPage(stack, CreateProfilePage)

            const btnCreateWithSeedPhrase = findChild(controlUnderTest, "btnCreateWithSeedPhrase")
            verify(!!btnCreateWithSeedPhrase)
            mouseClick(btnCreateWithSeedPhrase)

            // PAGE 3: Create profile using a recovery phrase
            page = getCurrentPage(stack, SeedphrasePage)

            const btnContinue = findChild(page, "btnContinue")
            verify(!!btnContinue)
            compare(btnContinue.enabled, false)

            const firstInput = findChild(page, "enterSeedPhraseInputField1")
            verify(!!firstInput)
            tryCompare(firstInput, "activeFocus", true)
            ClipboardUtils.setText(mockDriver.mnemonic)
            keySequence(StandardKey.Paste)
            compare(btnContinue.enabled, true)
            mouseClick(btnContinue)

            // PAGE 4: Create password
            page = getCurrentPage(stack, CreatePasswordPage)

            const btnConfirmPassword = findChild(controlUnderTest, "btnConfirmPassword")
            verify(!!btnConfirmPassword)
            compare(btnConfirmPassword.enabled, false)

            const passwordViewNewPassword = findChild(controlUnderTest, "passwordViewNewPassword")
            verify(!!passwordViewNewPassword)
            mouseClick(passwordViewNewPassword)
            compare(passwordViewNewPassword.activeFocus, true)
            compare(passwordViewNewPassword.text, "")

            keyClickSequence(mockDriver.dummyNewPassword)
            compare(passwordViewNewPassword.text, mockDriver.dummyNewPassword)
            compare(btnConfirmPassword.enabled, false)

            const passwordViewNewPasswordConfirm = findChild(controlUnderTest, "passwordViewNewPasswordConfirm")
            verify(!!passwordViewNewPasswordConfirm)
            mouseClick(passwordViewNewPasswordConfirm)
            compare(passwordViewNewPasswordConfirm.activeFocus, true)
            compare(passwordViewNewPasswordConfirm.text, "")

            keyClickSequence(mockDriver.dummyNewPassword)
            compare(passwordViewNewPassword.text, mockDriver.dummyNewPassword)
            compare(btnConfirmPassword.enabled, true)

            mouseClick(btnConfirmPassword)

            // PAGE 5: Enable Biometrics
            if (data.biometrics) {
                page = getCurrentPage(stack, EnableBiometricsPage)

                const enableBioButton = findChild(controlUnderTest, data.bioEnabled ? "btnEnableBiometrics" : "btnDontEnableBiometrics")
                dynamicSpy.setup(page, "enableBiometricsRequested")
                mouseClick(enableBioButton)
                tryCompare(dynamicSpy, "count", 1)
                compare(dynamicSpy.signalArguments[0][0], data.bioEnabled)
            }

            // FINISH
            tryCompare(finishedSpy, "count", 1)
            compare(finishedSpy.signalArguments[0][0], Onboarding.OnboardingFlow.CreateProfileWithSeedphrase)
            const resultData = finishedSpy.signalArguments[0][1]
            verify(!!resultData)
            compare(resultData.password, mockDriver.dummyNewPassword)
            compare(resultData.enableBiometrics, data.biometrics && data.bioEnabled)
            compare(resultData.keycardPin, "")
            compare(resultData.seedphrase, mockDriver.mnemonic)
        }

        // FLOW: Log in -> Log in with recovery phrase
        function test_flow_login_withSeedphrase(data) {
            verify(!!controlUnderTest)
            mockDriver.biometricsAvailable = data.biometrics

            const stack = controlUnderTest.stack
            verify(!!stack)

            // PAGE 1: Welcome
            let page = getCurrentPage(stack, WelcomePage)
            waitForRendering(page)

            const btnLogin = findChild(controlUnderTest, "btnLogin")
            verify(!!btnLogin)
            mouseClick(btnLogin)

            // PAGE 2: Log in -> Enter recovery phrase
            page = getCurrentPage(stack, NewAccountLoginPage)
            const btnWithSeedphrase = findChild(page, "btnWithSeedphrase")
            verify(!!btnWithSeedphrase)
            mouseClick(btnWithSeedphrase)

            // PAGE 3: Sign in with your Status recovery phrase
            page = getCurrentPage(stack, SeedphrasePage)

            const btnContinue = findChild(page, "btnContinue")
            verify(!!btnContinue)
            compare(btnContinue.enabled, false)

            const firstInput = findChild(page, "enterSeedPhraseInputField1")
            verify(!!firstInput)
            tryCompare(firstInput, "activeFocus", true)
            ClipboardUtils.setText(mockDriver.mnemonic)
            keySequence(StandardKey.Paste)
            compare(btnContinue.enabled, true)
            mouseClick(btnContinue)

            // PAGE 4: Create password
            page = getCurrentPage(stack, CreatePasswordPage)

            const btnConfirmPassword = findChild(controlUnderTest, "btnConfirmPassword")
            verify(!!btnConfirmPassword)
            compare(btnConfirmPassword.enabled, false)

            const passwordViewNewPassword = findChild(controlUnderTest, "passwordViewNewPassword")
            verify(!!passwordViewNewPassword)
            mouseClick(passwordViewNewPassword)
            compare(passwordViewNewPassword.activeFocus, true)
            compare(passwordViewNewPassword.text, "")

            keyClickSequence(mockDriver.dummyNewPassword)
            compare(passwordViewNewPassword.text, mockDriver.dummyNewPassword)
            compare(btnConfirmPassword.enabled, false)

            const passwordViewNewPasswordConfirm = findChild(controlUnderTest, "passwordViewNewPasswordConfirm")
            verify(!!passwordViewNewPasswordConfirm)
            mouseClick(passwordViewNewPasswordConfirm)
            compare(passwordViewNewPasswordConfirm.activeFocus, true)
            compare(passwordViewNewPasswordConfirm.text, "")

            keyClickSequence(mockDriver.dummyNewPassword)
            compare(passwordViewNewPassword.text, mockDriver.dummyNewPassword)
            compare(btnConfirmPassword.enabled, true)

            mouseClick(btnConfirmPassword)

            // PAGE 5: Local import
            page = getCurrentPage(stack, ImportLocalBackupPage)

            const btnSkipImport = findChild(controlUnderTest, "btnSkipImport")
            verify(!!btnSkipImport)
            mouseClick(btnSkipImport)

            // PAGE 6: Enable Biometrics
            if (data.biometrics) {
                page = getCurrentPage(stack, EnableBiometricsPage)

                const enableBioButton = findChild(controlUnderTest, data.bioEnabled ? "btnEnableBiometrics" : "btnDontEnableBiometrics")
                dynamicSpy.setup(page, "enableBiometricsRequested")
                mouseClick(enableBioButton)
                tryCompare(dynamicSpy, "count", 1)
                compare(dynamicSpy.signalArguments[0][0], data.bioEnabled)
            }

            tryCompare(finishedSpy, "count", 1)
            compare(finishedSpy.signalArguments[0][0], Onboarding.OnboardingFlow.LoginWithSeedphrase)
            const resultData = finishedSpy.signalArguments[0][1]
            verify(!!resultData)
            compare(resultData.password, mockDriver.dummyNewPassword)
            compare(resultData.enableBiometrics, data.biometrics && data.bioEnabled)
            compare(resultData.keycardPin, "")
            compare(resultData.seedphrase, mockDriver.mnemonic)
            compare(resultData.backupImportFileUrl, "")
        }

        // FLOW: Log in -> Log in by syncing
        function test_flow_login_bySyncing(data) {
            verify(!!controlUnderTest)
            mockDriver.biometricsAvailable = data.biometrics

            const stack = controlUnderTest.stack
            verify(!!stack)

            // PAGE 1: Welcome
            let page = getCurrentPage(stack, WelcomePage)
            waitForRendering(page)

            const btnLogin = findChild(controlUnderTest, "btnLogin")
            verify(!!btnLogin)
            mouseClick(btnLogin)

            // PAGE 2: Log in
            page = getCurrentPage(stack, NewAccountLoginPage)
            const btnBySyncing = findChild(page, "btnBySyncing")
            verify(!!btnBySyncing)
            mouseClick(btnBySyncing)

            const loginWithSyncAckPopup = findChild(page, "loginWithSyncAckPopup")
            verify(!!loginWithSyncAckPopup)
            tryVerify(() => loginWithSyncAckPopup.opened)

            let btnContinue = findChild(loginWithSyncAckPopup, "btnContinue")
            verify(!!btnContinue)
            compare(btnContinue.enabled, true)
            dynamicSpy.setup(page, "loginWithSyncingRequested")
            mouseClick(btnContinue)
            compare(btnContinue.enabled, false)
            tryCompare(dynamicSpy, "count", 1)
            //wait for the popup to close and to be removed
            tryVerify(() => !findChild(page, "loginWithSyncAckPopup"))

            // PAGE 3: Log in by syncing
            page = getCurrentPage(stack, LoginBySyncingPage)

            const enterCodeTabBtn = findChild(page, "secondTab_StatusSwitchTabButton")
            verify(!!enterCodeTabBtn)
            mouseClick(enterCodeTabBtn)

            btnContinue = findChild(page, "continue_StatusButton")
            verify(!!btnContinue)
            tryCompare(btnContinue, "enabled", false)

            const syncCodeInput = findChild(page, "syncCodeInput")
            verify(!!syncCodeInput)
            mouseClick(syncCodeInput)
            compare(syncCodeInput.input.edit.activeFocus, true)
            keyClickSequence("1234")
            tryCompare(btnContinue, "enabled", true)
            mouseClick(btnContinue)

            // PAGE 4: Profile sync in progress
            page = getCurrentPage(stack, SyncProgressPage)
            tryCompare(page, "syncState", Onboarding.LocalPairingState.Transferring)
            page.syncState = Onboarding.LocalPairingState.Finished // SIMULATION
            const btnLogin2 = findChild(page, "btnLogin") // TODO test other flows/buttons here as well
            verify(!!btnLogin2)
            tryCompare(btnLogin2, "visible", true)
            compare(btnLogin2.enabled, true)
            mouseClick(btnLogin2)

            // FINISH
            tryCompare(finishedSpy, "count", 1)
            compare(finishedSpy.signalArguments[0][0], Onboarding.OnboardingFlow.LoginWithSyncing)
            const resultData = finishedSpy.signalArguments[0][1]
            verify(!!resultData)
            compare(resultData.password, "")
            compare(resultData.keycardPin, "")
            compare(resultData.seedphrase, "")
        }

        // LOGIN SCREEN
        function test_loginScreen_data() {
            return [
              // password based profile ("uid_1")
              { tag: "correct password", keyUid: "uid_1", password: mockDriver.dummyNewPassword, biometrics: false },
              { tag: "correct password+biometrics", keyUid: "uid_1", password: mockDriver.dummyNewPassword, biometrics: true },
              { tag: "wrong password", keyUid: "uid_1", password: "foobar", biometrics: false },
              { tag: "wrong password+biometrics", keyUid: "uid_1", password: "foobar", biometrics: true },
              { tag: "non existing user", keyUid: "uid_xxx", password: "foobar", biometrics: false },
              { tag: "empty user", keyUid: "", password: "foobar", biometrics: false },
              // keycard based profile ("uid_4")
              { tag: "correct PIN", keyUid: "uid_4", pin: "111111", biometrics: false },
              { tag: "correct PIN+biometrics", keyUid: "uid_4", pin: "111111", biometrics: true },
              { tag: "wrong PIN", keyUid: "uid_4", pin: "123321", biometrics: false },
              { tag: "wrong PIN+biometrics", keyUid: "uid_4", pin: "123321", biometrics: true },
            ]
        }
        function test_loginScreen(data) {
            verify(!!controlUnderTest)
            controlUnderTest.onboardingStore.loginAccountsModel = loginAccountsModel
            controlUnderTest.restartFlow()

            mockDriver.biometricsAvailable = data.biometrics // both available _and_ enabled for this profile
            mockDriver.existingPin = "111111" // let this be the correct PIN

            const page = getCurrentPage(controlUnderTest.stack, LoginScreen)

            const userSelector = findChild(page, "loginUserSelector")
            verify(!!userSelector)
            userSelector.setSelection(data.keyUid) // select the right profile, keycard or regular one (password)

            expectFail("non existing user")
            expectFail("empty user")

            tryCompare(userSelector, "selectedProfileKeyId", data.keyUid)
            tryCompare(userSelector, "keycardCreatedAccount", !!data.pin && data.pin !== "")

            if (!!data.password) { // regular profile, no keycard
                const loginButton = findChild(page, "loginButton")
                verify(!!loginButton)
                tryCompare(loginButton, "visible", true)
                compare(loginButton.enabled, false)

                const passwordBox = findChild(page, "passwordBox")
                verify(!!passwordBox)

                const passwordInput = findChild(page, "loginPasswordInput")
                verify(!!passwordInput)
                tryCompare(passwordInput, "activeFocus", true)
                if (data.biometrics) { // biometrics + password
                    if (data.password === mockDriver.dummyNewPassword) { // expecting correct fingerprint
                        // simulate the external biometrics response
                        controlUnderTest.keychain.getCredentialRequestCompleted(
                                    Keychain.StatusSuccess, data.password)

                        tryCompare(passwordBox, "biometricsSuccessful", true)
                        tryCompare(passwordBox, "biometricsFailed", false)
                        tryCompare(passwordBox, "validationError", "")

                        // this fills the password and submits it, emits the loginRequested() signal below
                        tryCompare(passwordInput, "text", data.password)
                    } else { // expecting failed fetching credentials via biometrics
                        // simulate the external biometrics response
                        controlUnderTest.keychain.getCredentialRequestCompleted(
                                    Keychain.StatusGenericError, "")

                        tryCompare(passwordBox, "biometricsSuccessful", false)
                        tryCompare(passwordBox, "biometricsFailed", true)
                        tryCompare(passwordBox, "validationError", "Fetching credentials failed.")

                        // this fails and switches to the password method; so just verify we have an error and can enter the pass manually
                        tryCompare(passwordInput, "hasError", true)
                        tryCompare(passwordInput, "activeFocus", true)
                        tryCompare(passwordInput, "text", "")
                        expectFail(data.tag, "Biometrics failed, expected to fail to login")
                    }
                } else { // manual password
                    keyClickSequence(data.password)
                    tryCompare(passwordInput, "text", data.password)
                    compare(loginButton.enabled, true)
                    mouseClick(loginButton)
                }

                // verify the final "loginRequested" signal emission and params
                tryCompare(loginSpy, "count", 1)
                compare(loginSpy.signalArguments[0][0], data.keyUid)
                compare(loginSpy.signalArguments[0][1], Onboarding.LoginMethod.Password)
                const resultData = loginSpy.signalArguments[0][2]
                verify(!!resultData)
                compare(resultData.password, data.password)

                // verify validation & pass error
                tryCompare(passwordInput, "hasError", data.password !== mockDriver.dummyNewPassword)
            } else if (!!data.pin) { // keycard profile
                const pinInput = findChild(page, "pinInput")
                verify(!!pinInput)

                const keycardBox = findChild(page, "keycardBox")
                verify(!!keycardBox)

                if (data.biometrics) { // biometrics + PIN
                    mockDriver.keycardState = Onboarding.KeycardState.NotEmpty // triggers biometrics request
                    waitForRendering(keycardBox)
                    waitForItemPolished(keycardBox)

                    if (data.pin === mockDriver.existingPin) { // expecting correct fingerprint
                        // simulate the external biometrics response
                        controlUnderTest.keychain.getCredentialRequestCompleted(
                                    Keychain.StatusSuccess, data.pin)

                        tryCompare(keycardBox, "biometricsSuccessful", true)
                        tryCompare(keycardBox, "biometricsFailed", false)

                        // this fills the password and submits it, emits the loginRequested() signal below
                        tryCompare(pinInput, "pinInput", data.pin)
                    } else { // expecting failed fetching credentials via biometrics
                        // simulate the external biometrics response
                        controlUnderTest.keychain.getCredentialRequestCompleted(
                                    Keychain.StatusGenericError, "")

                        tryCompare(keycardBox, "biometricsSuccessful", false)
                        tryCompare(keycardBox, "biometricsFailed", true)

                        // this fails and lets the user enter the PIN manually; so just verify we have an error and empty PIN
                        tryCompare(pinInput, "pinInput", "")
                        expectFail(data.tag, "Biometrics failed, expected to fail to login")
                    }
                } else { // manual PIN
                    mockDriver.keycardState = Onboarding.KeycardState.NotEmpty // shows PIN input
                    tryCompare(pinInput, "visible", true)
                    compare(pinInput.pinInput, "")

                    waitForRendering(keycardBox)
                    waitForItemPolished(keycardBox)

                    keyClickSequence(data.pin)
                    if (data.pin !== mockDriver.existingPin) {
                        // Everything will still be called as with a good pin, the wrong pin return is async
                    }
                }

                // verify the final "loginRequested" signal emission and params
                tryCompare(loginSpy, "count", 1)
                compare(loginSpy.signalArguments[0][0], data.keyUid)
                compare(loginSpy.signalArguments[0][1], Onboarding.LoginMethod.Keycard)
                const resultData = loginSpy.signalArguments[0][2]
                verify(!!resultData)
                compare(resultData.pin, data.pin)
            }
        }

        function test_loginScreen_profileSelectionIsSavedAndRestoredAfterWrongPassword_data() {
            return [{ tag: "profile selection persisted after wrong password" }] // dummy to skip global data, and run just once
        }

        function test_loginScreen_profileSelectionIsSavedAndRestoredAfterWrongPassword() {
            verify(!!controlUnderTest)
            controlUnderTest.onboardingStore.loginAccountsModel = loginAccountsModel
            controlUnderTest.lastSelectedProfileKeyUid = "uid_1"
            controlUnderTest.restartFlow()

            let page = getCurrentPage(controlUnderTest.stack, LoginScreen)
            let userSelector = findChild(page, "loginUserSelector")
            verify(!!userSelector)
            tryCompare(userSelector, "selectedProfileKeyId", "uid_1")

            dynamicSpy.setup(controlUnderTest, "profileSelected")
            userSelector.setSelection("uid_2")

            // Validate that profile change notification is emitted so caller can persist it.
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], "uid_2")
            tryCompare(userSelector, "selectedProfileKeyId", "uid_2")

            // Simulate StartupOnboardingWrapper persisting selected profile UID.
            controlUnderTest.lastSelectedProfileKeyUid = dynamicSpy.signalArguments[0][0]

            const passwordInput = findChild(page, "loginPasswordInput")
            verify(!!passwordInput)
            mouseClick(passwordInput)
            keyClickSequence("wrong-password")

            const loginButton = findChild(page, "loginButton")
            verify(!!loginButton)
            tryCompare(loginButton, "enabled", true)
            mouseClick(loginButton)

            tryCompare(loginSpy, "count", 1)
            tryCompare(passwordInput, "hasError", true)

            // Simulate startup wrapper behavior on failed login.
            controlUnderTest.unwindToLoginScreen()

            page = getCurrentPage(controlUnderTest.stack, LoginScreen)
            userSelector = findChild(page, "loginUserSelector")
            verify(!!userSelector)
            // Validate that after a failed login attempt, the previously selected profile is still selected
            // (instead of resetting to default or first profile).
            tryCompare(userSelector, "selectedProfileKeyId", "uid_2")
        }

        function test_loginScreen_launchesExternalFlow_data() {
            return [
              { tag: "onboarding: create profile", delegateName: "createProfileDelegate", signalName: "onboardingCreateProfileFlowRequested", landingPage: CreateProfilePage },
              { tag: "onboarding: log in", delegateName: "logInDelegate", signalName: "onboardingLoginFlowRequested", landingPage: NewAccountLoginPage },
            ]
        }
        function test_loginScreen_launchesExternalFlow(data) {
            verify(!!controlUnderTest)
            controlUnderTest.onboardingStore.loginAccountsModel = loginAccountsModel
            controlUnderTest.restartFlow()

            let page = getCurrentPage(controlUnderTest.stack, LoginScreen)

            const loginUserSelector = findChild(page, "loginUserSelector")
            verify(!!loginUserSelector)
            mouseClick(loginUserSelector)

            const dropdown = findChild(loginUserSelector, "dropdown")
            verify(!!dropdown)
            tryCompare(dropdown, "opened", true)

            const menuDelegate = findChild(dropdown, data.delegateName)
            verify(!!menuDelegate)
            dynamicSpy.setup(page, data.signalName)
            mouseClick(menuDelegate)
            tryCompare(dynamicSpy, "count", 1)

            // PAGE 2: CreateProfilePage or NewAccountLoginPage
            tryVerify(() => {
                const currentPage = controlUnderTest.stack.currentItem
                return !!currentPage && currentPage instanceof data.landingPage
            })
        }

        function test_loginScreenLostKeycardSeedphraseLoginFlow_data() {
            return [{ tag: "lost keycard: start using without keycard" }] // dummy to skip global data, and run just once
        }

        function test_loginScreenLostKeycardSeedphraseLoginFlow() {
            skip("Lost keycard flow buttons are temporarily unavailable")
            verify(!!controlUnderTest)
            controlUnderTest.onboardingStore.loginAccountsModel = loginAccountsModel
            controlUnderTest.restartFlow()

            const stack = controlUnderTest.stack
            verify(!!stack)

            // PAGE 1: Login screen
            let page = getCurrentPage(stack, LoginScreen)
            const keyUid = "uid_4"

            const userSelector = findChild(page, "loginUserSelector")
            verify(!!userSelector)
            userSelector.setSelection(keyUid)
            tryCompare(userSelector, "selectedProfileKeyId", keyUid)
            tryCompare(userSelector, "keycardCreatedAccount", true)

            const lostKeycardButon = findChild(page, "lostKeycardButon")
            verify(!!lostKeycardButon)
            mouseClick(lostKeycardButon)

            // PAGE 2: Keycard lost page
            page = getCurrentPage(stack, KeycardLostPage)

            const startUsingWithoutKeycardButton = findChild(page, "startUsingWithoutKeycardButton")
            verify(!!startUsingWithoutKeycardButton)
            mouseClick(startUsingWithoutKeycardButton)

            // PAGE 3: Conversion acks page
            page = getCurrentPage(stack, ConvertKeycardAccountAcksPage)

            const continueButton = findChild(page, "continueButton")
            verify(!!continueButton)
            mouseClick(continueButton)

            // PAGE 4: Seedphrase
            page = getCurrentPage(stack, SeedphrasePage)

            const btnContinue = findChild(page, "btnContinue")
            verify(!!btnContinue)
            compare(btnContinue.enabled, false)

            const firstInput = findChild(page, "enterSeedPhraseInputField1")
            verify(!!firstInput)
            tryCompare(firstInput, "activeFocus", true)
            ClipboardUtils.setText(mockDriver.mnemonic)
            keySequence(StandardKey.Paste)
            compare(btnContinue.enabled, true)
            mouseClick(btnContinue)

            // PAGE 5: Create password
            page = getCurrentPage(stack, CreatePasswordPage)

            const btnConfirmPassword = findChild(page, "btnConfirmPassword")
            verify(!!btnConfirmPassword)
            compare(btnConfirmPassword.enabled, false)

            const passwordViewNewPassword = findChild(page, "passwordViewNewPassword")
            verify(!!passwordViewNewPassword)
            mouseClick(passwordViewNewPassword)
            compare(passwordViewNewPassword.activeFocus, true)
            compare(passwordViewNewPassword.text, "")

            keyClickSequence(mockDriver.dummyNewPassword)
            compare(passwordViewNewPassword.text, mockDriver.dummyNewPassword)
            compare(btnConfirmPassword.enabled, false)

            const passwordViewNewPasswordConfirm = findChild(page, "passwordViewNewPasswordConfirm")
            verify(!!passwordViewNewPasswordConfirm)
            mouseClick(passwordViewNewPasswordConfirm)
            compare(passwordViewNewPasswordConfirm.activeFocus, true)
            compare(passwordViewNewPasswordConfirm.text, "")

            keyClickSequence(mockDriver.dummyNewPassword)
            compare(passwordViewNewPassword.text, mockDriver.dummyNewPassword)
            compare(btnConfirmPassword.enabled, true)

            mouseClick(btnConfirmPassword)

            // FINISH
            tryCompare(finishedSpy, "count", 1)
            compare(finishedSpy.signalArguments[0][0], Onboarding.OnboardingFlow.LoginWithLostKeycardSeedphrase)
            const resultData = finishedSpy.signalArguments[0][1]
            verify(!!resultData)
            compare(resultData.password, mockDriver.dummyNewPassword)
            compare(resultData.enableBiometrics, false)
            compare(resultData.keycardPin, "")
            compare(resultData.seedphrase, mockDriver.mnemonic)
            compare(resultData.keyUid, keyUid)
        }

        function test_privacyModeFeatureEnabled_showsThirdPartyServices() {
            verify(!!controlUnderTest)

            // Get current page from stack (adjust LoginScreen to your actual root page type)
            const page = getCurrentPage(controlUnderTest.stack, WelcomePage)
            verify(!!page)

            // Find the thirdPartyServices component
            const thirdPartyServices = findChild(page, "thirdPartyServices")
            verify(!!thirdPartyServices)

            // Verify visibility
            tryCompare(thirdPartyServices, "visible", false)

            // Enable privacy mode feature
            controlUnderTest.privacyModeFeatureEnabled = true

            // Verify visibility
            tryCompare(thirdPartyServices, "visible", true)
        }


        function test_loginScreen_deleteProfile_data() {
            return [{ tag: "delete profile" }] // dummy to skip global data, and run just once
        }

        function test_loginScreen_deleteProfile(data) {
            verify(!!controlUnderTest)
            controlUnderTest.onboardingStore.loginAccountsModel = loginAccountsModel
            controlUnderTest.restartFlow()

            const page = getCurrentPage(controlUnderTest.stack, LoginScreen)
            verify(!!page)

            const onboardingFlow = findChild(controlUnderTest, "onboardingFlow")
            verify(!!onboardingFlow)

            const loginUserSelector = findChild(page, "loginUserSelector")
            verify(!!loginUserSelector)
            mouseClick(loginUserSelector)

            const dropdown = findChild(loginUserSelector, "dropdown")
            verify(!!dropdown)
            tryCompare(dropdown, "opened", true)

            const menuDelegate = findChild(dropdown, "manageProfilesDelegate")
            verify(!!menuDelegate)
            dynamicSpy.setup(page, "onboardingManageProfilesFlowRequested")
            mouseClick(menuDelegate)
            tryCompare(dynamicSpy, "count", 1)

            // Manage profile dialog
            const manageProfilesDialog = findChild(controlUnderTest, "manageProfilesDialog")
            verify(!!manageProfilesDialog)
            tryVerify( () => manageProfilesDialog.opened)

            const manageProfilesListView = findChild(manageProfilesDialog, "manageProfilesListView")
            verify(!!manageProfilesListView)

            const profileDelegate = findChild(manageProfilesListView, "manageProfilesDelegate-uid_3")
            verify(!!profileDelegate)

            const deleteButton = findChild(profileDelegate, "deleteProfileButton")
            verify(!!deleteButton)
            dynamicSpy.setup(profileDelegate, "deleteProfileRequested")
            mouseClick(deleteButton)
            tryCompare(dynamicSpy, "count", 1)

            // Confirmation dialog
            const deleteMultiaccountConfirmationDialog = findChild(controlUnderTest, "deleteMultiaccountConfirmationDialog")
            verify(!!deleteMultiaccountConfirmationDialog)
            tryVerify( () => deleteMultiaccountConfirmationDialog.opened)

            const confirmDeleteButton = findChild(deleteMultiaccountConfirmationDialog, "confirmDeleteMultiaccountBtn")
            verify(!!confirmDeleteButton)
            dynamicSpy.setup(onboardingFlow, "deleteMultiaccountRequested")
            mouseClick(confirmDeleteButton)
            tryCompare(dynamicSpy, "count", 1)
        }
    }
}
