pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import shared.panels

import AppLayouts.Onboarding
import AppLayouts.Onboarding.enums
import AppLayouts.Onboarding.stores
import AppLayouts.Onboarding.pages

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Platform

import QtModelsToolkit

Item {
    id: root

    property var featureFlagsStore
    property var languageStore
    property var keychain
    property string lastSelectedProfileKeyUid
    property bool biometricFlowPending

    signal appReady()
    signal requestMoveToAppMain()
    signal storeAppStateRequested()
    signal profileSelected(string keyUid)
    signal biometricFlowStarted()
    signal skippedBiometricFlow(bool available)
    signal contentLoaded()

    QtObject {
        id: d

        // Dev-only scripted onboarding, driven by the same scenario string as
        // AutoReproDriver: STATUS_AUTO_REPRO="<scenario>:password=...,login=<keyUid>"
        // logs into that profile (default: last selected, then first). With no
        // profiles on disk (or create=1) it creates a fresh password profile instead.
        // not named autoReproScenario: a same-named property would shadow the context property in its own binding
        readonly property string scenarioString: typeof autoReproScenario !== "undefined" ? autoReproScenario : ""

        function scenarioParam(key) {
            const match = scenarioString.match(new RegExp("[:,]" + key + "=([^,]*)"))
            return match ? match[1] : ""
        }

        function maybeAutoLogin() {
            const password = scenarioParam("password")
            if (password === "")
                return
            const model = onboardingStore.loginAccountsModel
            const hasProfiles = !!model && model.ModelCount.count > 0
            if (!hasProfiles || scenarioParam("create") === "1") {
                console.info("[autoRepro] scripted profile creation")
                onboardingLayout.finished(Onboarding.OnboardingFlow.CreateProfileWithPassword, {
                    selectedProfileKeyUid: "", password, keycardPin: "", seedphrase: "",
                    keyUid: "", backupImportFileUrl: "", enableBiometrics: false,
                    thirdpartyServicesEnabled: true, keycardPayload: null })
                return
            }
            let keyUid = scenarioParam("login") || root.lastSelectedProfileKeyUid
            if (keyUid === "")
                keyUid = SQUtils.ModelUtils.get(model, 0, "keyUid")
            console.info("[autoRepro] scripted password login for", keyUid)
            onboardingLayout.loginRequested(keyUid, Onboarding.LoginMethod.Password, { password })
        }
    }

    Component {
        id: splashScreenV2
        DidYouKnowSplashScreen {
            objectName: "splashScreenV2"
            readonly property bool backAvailableHint: false
            property bool runningProgressAnimation
            messagesEnabled: true
            infiniteLoading: runningProgressAnimation
        }
    }

    OnboardingLayout {
        id: onboardingLayout
        objectName: "startupOnboardingLayout"
        anchors.fill: parent

        isKeycardEnabled: root.featureFlagsStore.keycardEnabled
        lastSelectedProfileKeyUid: root.lastSelectedProfileKeyUid
        networkChecksEnabled: true

        onboardingStore: OnboardingStore {
            id: onboardingStore

            property bool loginRequestSent: false

            onAppLoaded: {
                root.appReady()
                root.storeAppStateRequested()

                if (!root.biometricFlowPending) {
                    root.requestMoveToAppMain()
                }
            }
            onAppShellReady: {
                if (!root.biometricFlowPending) {
                    Qt.callLater(() => root.requestMoveToAppMain())
                }
            }
            onAccountLoginError: function (error, wrongPassword) {
                onboardingStore.loginRequestSent = false

                // Pop the splash screen that onLoginRequested pushed, instead of unwinding — unwinding replaces the current screen
                const loginScreen = onboardingLayout.stack.loginScreen
                if (onboardingStore.keycardState === Onboarding.KeycardState.PairingPasswordRequired
                        && !!loginScreen) {
                    onboardingLayout.stack.pop(loginScreen)
                    return
                }

                if (loginScreen)
                    onboardingLayout.unwindToLoginScreen()
            }
            onSaveBiometricsRequested: (account, credential) => {
                root.biometricFlowStarted()
                root.keychain.saveCredential(account, credential)
            }
            onDeleteBiometricsRequested: (account) => {
                root.keychain.deleteCredential(account)
            }

            onKeycardStateChanged: {
                if (onboardingStore.loginRequestSent && keycardState === Onboarding.KeycardState.NotEmpty) {
                    // Show the splash screen if it's not already on top (on mobile it's pushed as soon as the login is requested)
                    const currentItem = onboardingLayout.stack.currentItem
                    if (!currentItem || currentItem.objectName !== "splashScreenV2")
                        onboardingLayout.stack.push(splashScreenV2, { runningProgressAnimation: true }, StackView.Immediate)
                } else if(keycardState === Onboarding.KeycardState.Cancelled) {
                    onboardingLayout.unwindToLoginScreen()
                }
            }
        }

        currentLanguage: root.languageStore.currentLanguage
        availableLanguages: root.languageStore.availableLanguages
        onChangeLanguageRequested: (newLanguageCode) => root.languageStore.changeLanguage(newLanguageCode, true)

        keychain: root.keychain

        privacyModeFeatureEnabled: root.featureFlagsStore.privacyModeFeatureEnabled

        onFinished: function(flow, data) {
            const error = onboardingStore.finishOnboardingFlow(flow, data)

            if (error !== "") {
                console.error("!!! ONBOARDING FINISHED WITH ERROR:", error)
                return
            }

            if (flow === Onboarding.OnboardingFlow.LoginWithLostKeycardSeedphrase) {
                onboardingLayout.stack.push(convertingKeycardAccountPage)
            } else {
                onboardingLayout.stack.push(splashScreenV2, {runningProgressAnimation: true})
            }
        }

        onProfileSelected: function (keyUid) {
            if (root.lastSelectedProfileKeyUid === keyUid) {
                return
            }
            root.profileSelected(keyUid)
        }

        onLoginRequested: function (keyUid, method, data) {
            let selectedProfile = SQUtils.ModelUtils.getByKey(onboardingStore.loginAccountsModel, "keyUid", keyUid)
            if (!selectedProfile) {
                console.error("cannot resolve selected profile")
                return
            }

            // Keycard login on desktop blocks until a card is inserted. The splash screen is pushed from onKeycardStateChanged
            // once the card is read. On mobile the OS NFC prompts for the card, so the splash is pushed right away.
            if (method !== Onboarding.LoginMethod.Keycard || SQUtils.Utils.isMobile)
                onboardingLayout.stack.push(splashScreenV2, { runningProgressAnimation: true }, StackView.Immediate)

            onboardingStore.loginRequestSent = true
            onboardingStore.loginRequested(keyUid, method, data)
        }

        onSkippedBiometricFlow: () => {
            root.skippedBiometricFlow(root.keychain.available)
        }

        Component.onCompleted: {
            root.contentLoaded()
            Qt.callLater(d.maybeAutoLogin)
        }

        Component {
            id: convertingKeycardAccountPage

            ConvertKeycardAccountPage {
                convertKeycardAccountState: onboardingStore.convertKeycardAccountState
                restartRequired: onboardingStore.convertKeycardAccountRestartRequired
                onRestartRequested: {
                    SystemUtils.restartApplication(true)
                }
                onBackToLoginRequested: {
                    onboardingStore.loginRequestSent = false
                    onboardingLayout.unwindToLoginScreen()
                }
            }
        }
    }
}
