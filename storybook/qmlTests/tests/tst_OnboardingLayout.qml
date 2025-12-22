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
        property int pinSettingState // enum Onboarding.ProgressState
        property int authorizationState // enum Onboarding.AuthorizationState
        property int restoreKeysExportState // enum Onboarding.ProgressState
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
                readonly property string keycardUID: "uid_4"
                readonly property int pinSettingState: mockDriver.pinSettingState // enum Onboarding.ProgressState
                readonly property int authorizationState: mockDriver.authorizationState // enum Onboarding.AuthorizationState
                readonly property int restoreKeysExportState: mockDriver.restoreKeysExportState // enum Onboarding.ProgressState
                property int keycardRemainingPinAttempts: Constants.onboarding.defaultPinAttempts
                property int keycardRemainingPukAttempts: Constants.onboarding.defaultPukAttempts
                property var loginAccountsModel: emptyModel

                function setPin(pin: string) {
                    const valid = pin === mockDriver.existingPin
                    if (!valid)
                        keycardRemainingPinAttempts--
                }

                function authorize(pin: string) {
                    authorizeCalled(pin)
                }
                function loadMnemonic(mnemonic: string) {
                    loadMnemonicCalled(mnemonic)
                }
                function exportRecoverKeys() {
                    exportRecoverKeysCalled()
                }

                readonly property int addKeyPairState: Onboarding.ProgressState.InProgress // enum Onboarding.ProgressState

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

                function generateMnemonic() { // -> string
                    return mockDriver.mnemonic
                }

                readonly property int syncState: Onboarding.ProgressState.InProgress // enum Onboarding.ProgressState
                function validateLocalPairingConnectionString(connectionString: string) {
                    return !Number.isNaN(parseInt(connectionString))
                }
                function inputConnectionStringForBootstrapping(connectionString: string) {}

                // password signals
                signal accountLoginError(string error, bool wrongPassword)

                signal authorizeCalled(string pin)
                signal loadMnemonicCalled(string mnemonic)
                signal exportRecoverKeysCalled
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

    SignalSpy {
        id: keycardRequestedSpy
        target: controlUnderTest
        signalName: "keycardRequested"
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
            mockDriver.pinSettingState = Onboarding.ProgressState.Idle
            mockDriver.authorizationState = Onboarding.AuthorizationState.Idle
            mockDriver.restoreKeysExportState = Onboarding.ProgressState.Idle
            mockDriver.biometricsAvailable = false
            mockDriver.existingPin = ""
            dynamicSpy.cleanup()
            finishedSpy.clear()
            loginSpy.clear()
            keycardRequestedSpy.clear()
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
            return [ { tag: "shareUsageData+bioEnabled", shareBtnName: "btnShare", shareResult: true, biometrics: true, bioEnabled: true },
                   { tag: "dontShareUsageData+bioEnabled", shareBtnName: "btnDontShare", shareResult: false, biometrics: true, bioEnabled: true },

                   { tag: "shareUsageData+bioDisabled", shareBtnName: "btnShare", shareResult: true, biometrics: true, bioEnabled: false },
                   { tag: "dontShareUsageData+bioDisabled", shareBtnName: "btnDontShare", shareResult: false, biometrics: true, bioEnabled: false },

                   { tag: "shareUsageData-bio", shareBtnName: "btnShare", shareResult: true, biometrics: false },
                   { tag: "dontShareUsageData-bio", shareBtnName: "btnDontShare", shareResult: false, biometrics: false },
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

            // PAGE 2: Help us improve
            page = getCurrentPage(stack, HelpUsImproveStatusPage)

            let infoButton = findChild(controlUnderTest, "infoButton")
            verify(!!infoButton)
            mouseClick(infoButton)
            const helpUsImproveDetailsPopup = findChild(controlUnderTest, "helpUsImproveDetailsPopup")
            verify(!!helpUsImproveDetailsPopup)
            tryVerify( () => helpUsImproveDetailsPopup.opened)
            keyClick(Qt.Key_Escape) // close the popup
            tryVerify( () => helpUsImproveDetailsPopup.exit ? !helpUsImproveDetailsPopup.exit.running : true)

            const shareButton = findChild(controlUnderTest, data.shareBtnName)
            dynamicSpy.setup(page, "shareUsageDataRequested")
            mouseClick(shareButton)
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], data.shareResult)

            // PAGE 3: Create profile
            page = getCurrentPage(stack, CreateProfilePage)

            const btnCreateWithPassword = findChild(controlUnderTest, "btnCreateWithPassword")
            verify(!!btnCreateWithPassword)
            mouseClick(btnCreateWithPassword)

            // PAGE 4: Create password
            page = getCurrentPage(stack, CreatePasswordPage)

            infoButton = findChild(controlUnderTest, "infoButton")
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

            // PAGE 2: Help us improve
            page = getCurrentPage(stack, HelpUsImproveStatusPage)

            const shareButton = findChild(controlUnderTest, data.shareBtnName)
            dynamicSpy.setup(page, "shareUsageDataRequested")
            mouseClick(shareButton)
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], data.shareResult)

            // PAGE 3: Create profile
            page = getCurrentPage(stack, CreateProfilePage)

            const btnCreateWithSeedPhrase = findChild(controlUnderTest, "btnCreateWithSeedPhrase")
            verify(!!btnCreateWithSeedPhrase)
            mouseClick(btnCreateWithSeedPhrase)

            // PAGE 4: Create profile using a recovery phrase
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

            // PAGE 6: Enable Biometrics
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

        // FLOW: Create Profile -> Use an empty Keycard -> Use a new recovery phrase (create profile with keycard + new seedphrase)
        function test_flow_createProfile_withKeycardAndNewSeedphrase(data) {
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

            // PAGE 2: Help us improve
            page = getCurrentPage(stack, HelpUsImproveStatusPage)
            const shareButton = findChild(controlUnderTest, data.shareBtnName)
            dynamicSpy.setup(page, "shareUsageDataRequested")
            mouseClick(shareButton)
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], data.shareResult)

            // PAGE 3: Create profile
            page = getCurrentPage(stack, CreateProfilePage)
            const btnCreateWithEmptyKeycard = findChild(controlUnderTest, "btnCreateWithEmptyKeycard")
            verify(!!btnCreateWithEmptyKeycard)
            mouseClick(btnCreateWithEmptyKeycard)

            // PAGE 4: Keycard intro
            page = getCurrentPage(stack, KeycardIntroPage)
            dynamicSpy.setup(page, "emptyKeycardDetected")
            mockDriver.keycardState = Onboarding.KeycardState.Empty // SIMULATION // TODO test other states here as well
            tryCompare(dynamicSpy, "count", 1)
            tryCompare(page, "state", "empty")

            // PAGE 5: Create profile on empty Keycard -> Use a new recovery phrase
            page = getCurrentPage(stack, CreateKeycardProfilePage)
            const btnCreateWithEmptySeedphrase = findChild(page, "btnCreateWithEmptySeedphrase")
            verify(!!btnCreateWithEmptySeedphrase)
            mouseClick(btnCreateWithEmptySeedphrase)

            // PAGE 6: Create new Keycard PIN
            const newPin = "123321"
            page = getCurrentPage(stack, KeycardCreatePinDelayedPage)
            dynamicSpy.setup(page, "setPinRequested")
            keyClickSequence(newPin + newPin) // set and repeat
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], newPin)
            mockDriver.pinSettingState = Onboarding.ProgressState.Success
            mockDriver.authorizationState = Onboarding.AuthorizationState.Authorized

            // PAGE 7: Backup your recovery phrase (intro)
            dynamicSpy.setup(stack, "topLevelItemChanged")
            tryCompare(dynamicSpy, "count", 1)
            page = getCurrentPage(stack, BackupSeedphraseIntro)
            const btnBackupSeedphrase = findChild(page, "btnBackupSeedphrase")
            verify(!!btnBackupSeedphrase)
            mouseClick(btnBackupSeedphrase)

            // PAGE 8: Backup your recovery phrase (seedphrase reveal) - step 1
            page = getCurrentPage(stack, BackupSeedphraseReveal)
            const seedGrid = findChild(page, "seedGrid")
            verify(!!seedGrid)
            tryCompare(seedGrid.layer, "enabled", true)
            const btnConfirm = findChild(page, "btnConfirm")
            verify(!!btnConfirm)
            compare(btnConfirm.enabled, false)
            const btnReveal = findChild(page, "btnReveal")
            verify(!!btnReveal)
            mouseClick(btnReveal)
            tryCompare(seedGrid.layer, "enabled", false)
            compare(btnConfirm.enabled, true)
            mouseClick(btnConfirm)

            // PAGE 9: Backup your recovery phrase (seedphrase verification) - step 2
            page = getCurrentPage(stack, BackupSeedphraseVerify)
            let btnContinue = findChild(page, "btnContinue")
            verify(!!btnContinue)
            compare(btnContinue.enabled, false)
            const mnemonicWords = page.verificationWordsMap.map((entry) => entry.seedWord)
            const mnemonicIndexes = page.verificationWordsMap.map((entry) => entry.seedWordNumber - 1)
            var mnemonicWordIndex = 0;
            for (const index of mnemonicIndexes) {
                const seedInput = findChild(page, "seedInput_%1".arg(index))
                verify(!!seedInput)
                mouseClick(seedInput)
                keyClickSequence(mnemonicWords[mnemonicWordIndex])
                keyClick(Qt.Key_Tab)
                mnemonicWordIndex++;
            }

            compare(btnContinue.enabled, true)
            mouseClick(btnContinue)

            // PAGE 10: Backup your recovery phrase (outro) - step 3
            page = getCurrentPage(stack, BackupSeedphraseOutro)
            btnContinue = findChild(page, "btnContinue")
            verify(!!btnContinue)
            compare(btnContinue.enabled, false)
            const cbAck = findChild(page, "cbAck")
            verify(!!cbAck)
            compare(cbAck.checked, false)
            mouseClick(cbAck)
            compare(cbAck.checked, true)
            compare(btnContinue.enabled, true)
            mouseClick(btnContinue)

            // PAGE 11: Adding key pair to Keycard
            page = getCurrentPage(stack, KeycardAddKeyPairDelayedPage)
            tryCompare(page, "addKeyPairState", Onboarding.ProgressState.InProgress)
            page.addKeyPairState = Onboarding.ProgressState.Success // SIMULATION

            // PAGE 12: Enable Biometrics
            if (data.biometrics) {
                dynamicSpy.setup(stack, "topLevelItemChanged")
                tryCompare(dynamicSpy, "count", 1)

                page = getCurrentPage(stack, EnableBiometricsPage)

                const enableBioButton = findChild(controlUnderTest, data.bioEnabled ? "btnEnableBiometrics" : "btnDontEnableBiometrics")
                dynamicSpy.setup(page, "enableBiometricsRequested")
                mouseClick(enableBioButton)
                tryCompare(dynamicSpy, "count", 1)
                compare(dynamicSpy.signalArguments[0][0], data.bioEnabled)
            }

            // FINISH
            tryCompare(finishedSpy, "count", 1)
            compare(finishedSpy.signalArguments[0][0], Onboarding.OnboardingFlow.CreateProfileWithKeycardNewSeedphrase)
            const resultData = finishedSpy.signalArguments[0][1]
            verify(!!resultData)
            compare(resultData.password, "")
            compare(resultData.enableBiometrics, data.biometrics && data.bioEnabled)
            compare(resultData.keycardPin, newPin)
            compare(resultData.seedphrase, mockDriver.mnemonic)
        }

        // FLOW: Create Profile -> Use an empty Keycard -> Use an existing recovery phrase (create profile with keycard + existing seedphrase)
        function test_flow_createProfile_withKeycardAndExistingSeedphrase(data) {
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

            // PAGE 2: Help us improve
            page = getCurrentPage(stack, HelpUsImproveStatusPage)
            const shareButton = findChild(controlUnderTest, data.shareBtnName)
            dynamicSpy.setup(page, "shareUsageDataRequested")
            mouseClick(shareButton)
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], data.shareResult)

            // PAGE 3: Create profile
            page = getCurrentPage(stack, CreateProfilePage)
            const btnCreateWithEmptyKeycard = findChild(controlUnderTest, "btnCreateWithEmptyKeycard")
            verify(!!btnCreateWithEmptyKeycard)
            mouseClick(btnCreateWithEmptyKeycard)

            // PAGE 4: Keycard intro
            page = getCurrentPage(stack, KeycardIntroPage)
            dynamicSpy.setup(page, "emptyKeycardDetected")
            mockDriver.keycardState = Onboarding.KeycardState.Empty // SIMULATION // TODO test other states here as well
            tryCompare(dynamicSpy, "count", 1)
            tryCompare(page, "state", "empty")

            // PAGE 5: Create profile on empty Keycard -> Use an existing recovery phrase
            page = getCurrentPage(stack, CreateKeycardProfilePage)
            const btnCreateWithExistingSeedphrase = findChild(page, "btnCreateWithExistingSeedphrase")
            verify(!!btnCreateWithExistingSeedphrase)
            mouseClick(btnCreateWithExistingSeedphrase)

            // PAGE 6: Create profile on empty Keycard using a recovery phrase
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

            // PAGE 7: Create new Keycard PIN
            const newPin = "123321"
            page = getCurrentPage(stack, KeycardCreatePinDelayedPage)
            dynamicSpy.setup(page, "setPinRequested")
            keyClickSequence(newPin + newPin) // set and repeat
            compare(dynamicSpy.signalArguments[0][0], newPin)
            mockDriver.pinSettingState = Onboarding.ProgressState.Success
            mockDriver.authorizationState = Onboarding.AuthorizationState.Authorized

            // PAGE 8: Adding key pair to Keycard
            dynamicSpy.setup(stack, "topLevelItemChanged")
            tryCompare(dynamicSpy, "count", 1)
            page = getCurrentPage(stack, KeycardAddKeyPairDelayedPage)
            tryCompare(page, "addKeyPairState", Onboarding.ProgressState.InProgress)
            page.addKeyPairState = Onboarding.ProgressState.Success // SIMULATION

            // PAGE 9: Enable Biometrics
            if (mockDriver.biometricsAvailable) {
                dynamicSpy.setup(stack, "topLevelItemChanged")
                tryCompare(dynamicSpy, "count", 1)

                page = getCurrentPage(stack, EnableBiometricsPage)

                const enableBioButton = findChild(controlUnderTest, data.bioEnabled ? "btnEnableBiometrics" : "btnDontEnableBiometrics")
                dynamicSpy.setup(page, "enableBiometricsRequested")
                mouseClick(enableBioButton)
                tryCompare(dynamicSpy, "count", 1)
                compare(dynamicSpy.signalArguments[0][0], data.bioEnabled)
            }

            // FINISH
            tryCompare(finishedSpy, "count", 1)
            compare(finishedSpy.signalArguments[0][0], Onboarding.OnboardingFlow.CreateProfileWithKeycardExistingSeedphrase)
            const resultData = finishedSpy.signalArguments[0][1]
            verify(!!resultData)
            compare(resultData.password, "")
            compare(resultData.enableBiometrics, data.biometrics && data.bioEnabled)
            compare(resultData.keycardPin, newPin)
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

            // PAGE 2: Help us improve
            page = getCurrentPage(stack, HelpUsImproveStatusPage)
            const shareButton = findChild(controlUnderTest, data.shareBtnName)
            dynamicSpy.setup(page, "shareUsageDataRequested")
            mouseClick(shareButton)
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], data.shareResult)

            // PAGE 3: Log in -> Enter recovery phrase
            page = getCurrentPage(stack, NewAccountLoginPage)
            const btnWithSeedphrase = findChild(page, "btnWithSeedphrase")
            verify(!!btnWithSeedphrase)
            mouseClick(btnWithSeedphrase)

            // PAGE 4: Sign in with your Status recovery phrase
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

            // PAGE 6: Local import
            page = getCurrentPage(stack, ImportLocalBackupPage)

            const btnSkipImport = findChild(controlUnderTest, "btnSkipImport")
            verify(!!btnSkipImport)
            mouseClick(btnSkipImport)

            // PAGE 7: Enable Biometrics
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

            // PAGE 2: Help us improve
            page = getCurrentPage(stack, HelpUsImproveStatusPage)
            const shareButton = findChild(controlUnderTest, data.shareBtnName)
            dynamicSpy.setup(page, "shareUsageDataRequested")
            mouseClick(shareButton)
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], data.shareResult)

            // PAGE 3: Log in
            page = getCurrentPage(stack, NewAccountLoginPage)
            const btnBySyncing = findChild(page, "btnBySyncing")
            verify(!!btnBySyncing)
            mouseClick(btnBySyncing)

            const loginWithSyncAckPopup = findChild(page, "loginWithSyncAckPopup")
            verify(!!loginWithSyncAckPopup)
            tryVerify(() => loginWithSyncAckPopup.opened)

            let btnContinue = findChild(loginWithSyncAckPopup, "btnContinue")
            verify(!!btnContinue)
            compare(btnContinue.enabled, false)
            for (let ack of ["ack1", "ack2", "ack3"]) {
                const cb = findChild(loginWithSyncAckPopup, ack)
                verify(!!cb)
                mouseClick(cb)
            }
            tryCompare(btnContinue, "enabled", true)
            mouseClick(btnContinue)
            tryVerify(() => loginWithSyncAckPopup.exit ? !loginWithSyncAckPopup.exit.running : true)

            // PAGE 4: Log in by syncing
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

            // PAGE 5: Profile sync in progress
            page = getCurrentPage(stack, SyncProgressPage)
            tryCompare(page, "syncState", Onboarding.LocalPairingState.Transferring)
            page.syncState = Onboarding.LocalPairingState.Finished // SIMULATION
            const btnLogin2 = findChild(page, "btnLogin") // TODO test other flows/buttons here as well
            verify(!!btnLogin2)
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

        // FLOW: Log in -> Log in with Keycard
        function test_flow_login_withKeycard(data) {
            verify(!!controlUnderTest)
            mockDriver.biometricsAvailable = data.biometrics
            mockDriver.existingPin = "123456"

            const stack = controlUnderTest.stack
            verify(!!stack)

            // PAGE 1: Welcome
            let page = getCurrentPage(stack, WelcomePage)
            waitForRendering(page)

            const btnLogin = findChild(controlUnderTest, "btnLogin")
            verify(!!btnLogin)
            mouseClick(btnLogin)

            // PAGE 2: Help us improve
            page = getCurrentPage(stack, HelpUsImproveStatusPage)
            const shareButton = findChild(controlUnderTest, data.shareBtnName)
            dynamicSpy.setup(page, "shareUsageDataRequested")
            mouseClick(shareButton)
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], data.shareResult)

            // PAGE 3: Log in -> Login with Keycard
            page = getCurrentPage(stack, NewAccountLoginPage)
            const btnWithKeycard = findChild(page, "btnWithKeycard")
            verify(!!btnWithKeycard)
            mouseClick(btnWithKeycard)

            // PAGE 4: Keycard intro
            page = getCurrentPage(stack, KeycardIntroPage)
            dynamicSpy.setup(page, "notEmptyKeycardDetected")
            mockDriver.keycardState = Onboarding.KeycardState.NotEmpty // SIMULATION // TODO test other states here as well
            tryCompare(dynamicSpy, "count", 1)
            tryCompare(page, "state", "notEmpty")

            // PAGE 5: Enter Keycard PIN
            page = getCurrentPage(stack, KeycardEnterPinPage)
            dynamicSpy.setup(controlUnderTest.onboardingStore, "authorizeCalled")
            keyClickSequence(mockDriver.existingPin)
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], mockDriver.existingPin)

            dynamicSpy.setup(controlUnderTest.onboardingStore, "exportRecoverKeysCalled")
            mockDriver.authorizationState = Onboarding.AuthorizationState.Authorized
            tryCompare(dynamicSpy, "count", 1)

            // PAGE 6: Extracting keys from Keycard
            page = getCurrentPage(stack, KeycardIntroPage)
            tryCompare(page, "keycardState", Onboarding.KeycardState.ReadingKeycard)
            mockDriver.restoreKeysExportState = Onboarding.ProgressState.Success

            // PAGE 7: Local import
            waitForRendering(page)
            page = getCurrentPage(stack, ImportLocalBackupPage)

            const btnSkipImport = findChild(controlUnderTest, "btnSkipImport")
            verify(!!btnSkipImport)
            mouseClick(btnSkipImport)

            // FINISH
            tryCompare(finishedSpy, "count", 1)
            compare(finishedSpy.signalArguments[0][0], Onboarding.OnboardingFlow.LoginWithKeycard)
            const resultData = finishedSpy.signalArguments[0][1]
            verify(!!resultData)
            compare(resultData.password, "")
            compare(resultData.keycardPin, "")
            compare(resultData.seedphrase, "")
            compare(resultData.backupImportFileUrl, "")
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
                mockDriver.keycardState = Onboarding.KeycardState.NotEmpty // happy path; keycard ready
                const pinInput = findChild(page, "pinInput")
                verify(!!pinInput)
                tryCompare(pinInput, "visible", true)
                compare(pinInput.pinInput, "")

                const keycardBox = findChild(page, "keycardBox")
                verify(!!keycardBox)

                if (data.biometrics) { // biometrics + PIN
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

        function test_loginScreen_launchesExternalFlow_data() {
            return [
              { tag: "onboarding: create profile", delegateName: "createProfileDelegate", signalName: "onboardingCreateProfileFlowRequested", landingPage: CreateProfilePage },
              { tag: "onboarding: log in", delegateName: "logInDelegate", signalName: "onboardingLoginFlowRequested", landingPage: NewAccountLoginPage },
            ]
        }
        function test_loginScreen_launchesExternalFlow(data) {
            verify(!!controlUnderTest)
            controlUnderTest.onboardingStore.loginAccountsModel = loginAccountsModel

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

            // PAGE 2: Help us improve
            page = getCurrentPage(controlUnderTest.stack, HelpUsImproveStatusPage)

            const shareButton = findChild(controlUnderTest, "btnShare")
            dynamicSpy.setup(page, "shareUsageDataRequested")
            mouseClick(shareButton)
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], true)

            // PAGE 3: CreateProfilePage or NewAccountLoginPage
            tryVerify(() => {
                const currentPage = controlUnderTest.stack.currentItem
                return !!currentPage && currentPage instanceof data.landingPage
            })
        }

        function test_loginScreenLostKeycardSeedphraseLoginFlow_data() {
            return [{ tag: "lost keycard: start using without keycard" }] // dummy to skip global data, and run just once
        }

        function test_loginScreenLostKeycardSeedphraseLoginFlow() {
            verify(!!controlUnderTest)
            controlUnderTest.onboardingStore.loginAccountsModel = loginAccountsModel

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

        function test_loginScreenLostKeycardCreateReplacementFlow_data() {
            return [{ tag: "lost keycard: create replacement keycard" }] // dummy to skip global data, and run just once
        }

        function test_loginScreenLostKeycardCreateReplacementFlow() {
            verify(!!controlUnderTest)
            controlUnderTest.onboardingStore.loginAccountsModel = loginAccountsModel

            // PAGE 1: Login screen
            const stack = controlUnderTest.stack
            verify(!!stack)

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

            const createReplacementButton = findChild(page, "createReplacementButton")
            verify(!!createReplacementButton)
            mouseClick(createReplacementButton)

            // PAGE 3: Keycard intro
            page = getCurrentPage(stack, KeycardIntroPage)
            dynamicSpy.setup(page, "emptyKeycardDetected")
            mockDriver.keycardState = Onboarding.KeycardState.Empty // SIMULATION // TODO test other states here as well
            tryCompare(dynamicSpy, "count", 1)
            tryCompare(page, "state", "empty")

            // PAGE 4: Seedphrase
            page = getCurrentPage(stack, SeedphrasePage)
            let btnContinue = findChild(page, "btnContinue")
            verify(!!btnContinue)
            compare(btnContinue.enabled, false)

            const firstInput = findChild(page, "enterSeedPhraseInputField1")
            verify(!!firstInput)
            tryCompare(firstInput, "activeFocus", true)
            ClipboardUtils.setText(mockDriver.mnemonic)
            keySequence(StandardKey.Paste)
            compare(btnContinue.enabled, true)
            mouseClick(btnContinue)

            // PAGE 5: Create new Keycard PIN
            const newPin = "123321"
            page = getCurrentPage(stack, KeycardCreatePinDelayedPage)
            dynamicSpy.setup(page, "setPinRequested")
            keyClickSequence(newPin + newPin) // set and repeat
            tryCompare(dynamicSpy, "count", 1)
            compare(dynamicSpy.signalArguments[0][0], newPin)
            mockDriver.pinSettingState = Onboarding.ProgressState.Success
            mockDriver.authorizationState = Onboarding.AuthorizationState.Authorized

            // PAGE 6: Adding key pair to Keycard
            dynamicSpy.setup(stack, "topLevelItemChanged")
            tryCompare(dynamicSpy, "count", 1)
            page = getCurrentPage(stack, KeycardAddKeyPairDelayedPage)
            tryCompare(page, "addKeyPairState", Onboarding.ProgressState.InProgress)
            page.addKeyPairState = Onboarding.ProgressState.Success // SIMULATION

            // FINISH
            tryCompare(finishedSpy, "count", 1)
            compare(finishedSpy.signalArguments[0][0], Onboarding.OnboardingFlow.LoginWithRestoredKeycard)
            const resultData = finishedSpy.signalArguments[0][1]
            verify(!!resultData)
            compare(resultData.enableBiometrics, false)
            compare(resultData.keycardPin, newPin)
            compare(resultData.seedphrase, mockDriver.mnemonic)
        }

        function test_loginScreen_unblockFlows_data() {
            return [
              { tag: "Unblock with PUK", keyUid: "uid_4", btnName: "btnUnblockWithPUK", landingPage: KeycardEnterPukPage },
              { tag: "Unblock with recovery phrase", keyUid: "uid_4", btnName: "btnUnblockWithSeedphrase", landingPage: SeedphrasePage },
            ]
        }

        function test_loginScreen_unblockFlows(data) {
            verify(!!controlUnderTest)
            controlUnderTest.onboardingStore.loginAccountsModel = loginAccountsModel
            mockDriver.keycardState = Onboarding.KeycardState.BlockedPIN

            const page = getCurrentPage(controlUnderTest.stack, LoginScreen)

            const loginUserSelector = findChild(page, "loginUserSelector")
            verify(!!loginUserSelector)
            loginUserSelector.setSelection(data.keyUid)

            tryCompare(page, "selectedProfileKeyId", data.keyUid)
            tryCompare(page, "selectedProfileIsKeycard", true)

            const keycardBox = findChild(page, "keycardBox")
            verify(!!keycardBox)
            tryCompare(keycardBox, "visible", true)
            tryCompare(keycardBox, "state", "blocked")

            waitForRendering(page)

            const button = findChild(keycardBox, data.btnName)
            verify(!!button)
            tryCompare(button, "visible", true)
            mouseClick(button)

            tryVerify(() => {
                const currentPage = controlUnderTest.stack.topLevelItem
                return !!currentPage && currentPage instanceof data.landingPage
            })

            // TODO extend the check with trying to complete the flows
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

        // TEST: Keycard requested signal emission tests
        function test_keycardRequested_createProfileWithKeycard_data() {
            return [{ tag: "create profile with keycard" }] // dummy to skip global data
        }

        function test_keycardRequested_createProfileWithKeycard() {
            verify(!!controlUnderTest)

            const stack = controlUnderTest.stack
            verify(!!stack)

            // PAGE 1: Welcome
            let page = getCurrentPage(stack, WelcomePage)
            waitForRendering(page)

            const btnCreateProfile = findChild(controlUnderTest, "btnCreateProfile")
            verify(!!btnCreateProfile)
            mouseClick(btnCreateProfile)

            // PAGE 2: Help us improve
            page = getCurrentPage(stack, HelpUsImproveStatusPage)
            const shareButton = findChild(controlUnderTest, "btnShare")
            mouseClick(shareButton)

            // PAGE 3: Create profile
            page = getCurrentPage(stack, CreateProfilePage)
            const btnCreateWithEmptyKeycard = findChild(controlUnderTest, "btnCreateWithEmptyKeycard")
            verify(!!btnCreateWithEmptyKeycard)

            // Verify keycardRequested signal is NOT yet emitted
            compare(keycardRequestedSpy.count, 0)

            // Click the button to create with keycard
            mouseClick(btnCreateWithEmptyKeycard)

            // Verify keycardRequested signal WAS emitted
            tryCompare(keycardRequestedSpy, "count", 1)
        }

        function test_keycardRequested_loginWithKeycard_data() {
            return [{ tag: "login with keycard" }] // dummy to skip global data
        }

        function test_keycardRequested_loginWithKeycard() {
            verify(!!controlUnderTest)

            const stack = controlUnderTest.stack
            verify(!!stack)

            // PAGE 1: Welcome
            let page = getCurrentPage(stack, WelcomePage)
            waitForRendering(page)

            const btnLogin = findChild(controlUnderTest, "btnLogin")
            verify(!!btnLogin)
            mouseClick(btnLogin)

            // PAGE 2: Help us improve
            page = getCurrentPage(stack, HelpUsImproveStatusPage)
            const shareButton = findChild(controlUnderTest, "btnShare")
            mouseClick(shareButton)

            // PAGE 3: Log in
            page = getCurrentPage(stack, NewAccountLoginPage)
            const btnWithKeycard = findChild(page, "btnWithKeycard")
            verify(!!btnWithKeycard)

            // Verify keycardRequested signal is NOT yet emitted
            compare(keycardRequestedSpy.count, 0)

            // Click the button to login with keycard
            mouseClick(btnWithKeycard)

            // Verify keycardRequested signal WAS emitted
            tryCompare(keycardRequestedSpy, "count", 1)
        }

        function test_keycardRequested_selectKeycardProfileOnLoginScreen_data() {
            return [{ tag: "select keycard profile" }] // dummy to skip global data
        }

        function test_keycardRequested_selectKeycardProfileOnLoginScreen() {
            verify(!!controlUnderTest)
            controlUnderTest.onboardingStore.loginAccountsModel = loginAccountsModel

            const page = getCurrentPage(controlUnderTest.stack, LoginScreen)

            const userSelector = findChild(page, "loginUserSelector")
            verify(!!userSelector)

            // Initially select a password-based profile (uid_1)
            userSelector.setSelection("uid_1")
            tryCompare(userSelector, "selectedProfileKeyId", "uid_1")
            tryCompare(userSelector, "keycardCreatedAccount", false)

            // Clear any signals emitted during initial setup (LoginScreen may auto-select a profile)
            keycardRequestedSpy.clear()

            // Verify keycardRequested signal is NOT emitted for password profile (after clearing)
            compare(keycardRequestedSpy.count, 0)

            // Now select a keycard profile (uid_4)
            userSelector.setSelection("uid_4")
            tryCompare(userSelector, "selectedProfileKeyId", "uid_4")
            tryCompare(userSelector, "keycardCreatedAccount", true)

            // Verify keycardRequested signal WAS emitted when switching to keycard profile
            tryCompare(keycardRequestedSpy, "count", 1)
        }

        function test_keycardRequested_notEmittedForPasswordFlow_data() {
            return [{ tag: "password flow" }] // dummy to skip global data
        }

        function test_keycardRequested_notEmittedForPasswordFlow() {
            verify(!!controlUnderTest)

            const stack = controlUnderTest.stack
            verify(!!stack)

            // PAGE 1: Welcome
            let page = getCurrentPage(stack, WelcomePage)
            waitForRendering(page)

            const btnCreateProfile = findChild(controlUnderTest, "btnCreateProfile")
            verify(!!btnCreateProfile)
            mouseClick(btnCreateProfile)

            // PAGE 2: Help us improve
            page = getCurrentPage(stack, HelpUsImproveStatusPage)
            const shareButton = findChild(controlUnderTest, "btnShare")
            mouseClick(shareButton)

            // PAGE 3: Create profile
            page = getCurrentPage(stack, CreateProfilePage)
            const btnCreateWithPassword = findChild(controlUnderTest, "btnCreateWithPassword")
            verify(!!btnCreateWithPassword)
            mouseClick(btnCreateWithPassword)

            // PAGE 4: Create password
            page = getCurrentPage(stack, CreatePasswordPage)

            // Verify keycardRequested signal was NOT emitted throughout the password flow
            compare(keycardRequestedSpy.count, 0)
        }
    }
}
