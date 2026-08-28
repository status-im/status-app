pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import shared.panels

import AppLayouts.Onboarding
import AppLayouts.Onboarding.enums
import AppLayouts.Onboarding.stores
import AppLayouts.Onboarding.pages

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Platform

Item {
    id: root

    property var featureFlagsStore
    property var languageStore
    property var keychain
    property var secureStorage
    property bool autoLoginEnabled
    property string lastSelectedProfileKeyUid
    property bool biometricFlowPending

    // Injectable for tests; the default instance is backed by the onboarding module
    // context property, exactly as before.
    property var onboardingStore: defaultOnboardingStore

    signal appReady()
    signal requestMoveToAppMain()
    signal storeAppStateRequested()
    signal profileSelected(string keyUid)
    signal biometricFlowStarted()
    signal skippedBiometricFlow(bool available)
    signal contentLoaded()

    OnboardingStore {
        id: defaultOnboardingStore
    }

    QtObject {
        id: d

        property bool loginRequestSent: false
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

    Connections {
        target: root.onboardingStore

        function onAppLoaded() {
            root.appReady()
            root.storeAppStateRequested()

            if (!root.biometricFlowPending) {
                root.requestMoveToAppMain()
            }
        }

        function onAppShellReady() {
            if (!root.biometricFlowPending) {
                Qt.callLater(() => root.requestMoveToAppMain())
            }
        }

        function onAccountLoginError(error, wrongPassword) {
            d.loginRequestSent = false

            // A failed silent auto-login falls back to the normal login screen. The
            // stored credential is stale (e.g. the DEK was rotated elsewhere, or a
            // rekey is pending) — remove it so the next launch doesn't retry. The
            // preference survives: the next successful manual login re-stores a
            // fresh credential. Consume-once with the RECORDED key UID: a later
            // manual-login error (possibly on another profile) finds nothing to
            // delete.
            const staleAutoLoginKeyUid = onboardingLayout.consumeAutoLoginFailure()
            if (staleAutoLoginKeyUid !== "" && root.secureStorage)
                root.secureStorage.deleteCredential(staleAutoLoginKeyUid)

            // Pop the splash screen that onLoginRequested pushed, instead of unwinding — unwinding replaces the current screen
            const loginScreen = onboardingLayout.stack.loginScreen
            if (root.onboardingStore.keycardState === Onboarding.KeycardState.PairingPasswordRequired
                    && !!loginScreen) {
                onboardingLayout.stack.pop(loginScreen)
                return
            }

            if (loginScreen)
                onboardingLayout.unwindToLoginScreen()
        }

        function onSaveBiometricsRequested(account, credential) {
            root.biometricFlowStarted()
            root.keychain.saveCredential(account, credential)
        }

        function onDeleteBiometricsRequested(account) {
            root.keychain.deleteCredential(account)
        }

        function onStayLoggedInSaveRequested(account, credential, enablePreference) {
            // The credential is guaranteed dek-tagged (enforced Nim-side). The
            // preference survives logout by design: with it ON, an explicit login
            // silently re-stores the credential; with it OFF, any stale credential
            // is reconciled away (the final safety net for a mutation that
            // committed after its caller timed out).
            if (enablePreference)
                localAccountSettings.stayLoggedIn = true
            if (localAccountSettings.stayLoggedIn)
                root.secureStorage.setCredential(account, credential)
            else if (root.secureStorage.hasCredential(account) === SecureStorage.StatusSuccess)
                root.secureStorage.deleteCredential(account)
        }

        function onKeycardStateChanged() {
            if (d.loginRequestSent && root.onboardingStore.keycardState === Onboarding.KeycardState.NotEmpty) {
                // Show the splash screen if it's not already on top (on mobile it's pushed as soon as the login is requested)
                const currentItem = onboardingLayout.stack.currentItem
                if (!currentItem || currentItem.objectName !== "splashScreenV2")
                    onboardingLayout.stack.push(splashScreenV2, { runningProgressAnimation: true }, StackView.Immediate)
            } else if (root.onboardingStore.keycardState === Onboarding.KeycardState.Cancelled) {
                onboardingLayout.unwindToLoginScreen()
            }
        }
    }

    OnboardingLayout {
        id: onboardingLayout
        objectName: "startupOnboardingLayout"
        anchors.fill: parent

        isKeycardEnabled: root.featureFlagsStore.keycardEnabled
        lastSelectedProfileKeyUid: root.lastSelectedProfileKeyUid
        networkChecksEnabled: true

        onboardingStore: root.onboardingStore

        currentLanguage: root.languageStore.currentLanguage
        availableLanguages: root.languageStore.availableLanguages
        onChangeLanguageRequested: (newLanguageCode) => root.languageStore.changeLanguage(newLanguageCode, true)

        keychain: root.keychain
        secureStorage: root.secureStorage
        autoLoginEnabled: root.autoLoginEnabled

        privacyModeFeatureEnabled: root.featureFlagsStore.privacyModeFeatureEnabled

        onFinished: function(flow, data) {
            const error = root.onboardingStore.finishOnboardingFlow(flow, data)

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
            let selectedProfile = SQUtils.ModelUtils.getByKey(root.onboardingStore.loginAccountsModel, "keyUid", keyUid)
            if (!selectedProfile) {
                console.error("cannot resolve selected profile")
                return
            }

            // Keycard login on desktop blocks until a card is inserted. The splash screen is pushed from onKeycardStateChanged
            // once the card is read. On mobile the OS NFC prompts for the card, so the splash is pushed right away.
            if (method !== Onboarding.LoginMethod.Keycard || SQUtils.Utils.isMobile)
                onboardingLayout.stack.push(splashScreenV2, { runningProgressAnimation: true }, StackView.Immediate)

            d.loginRequestSent = true
            root.onboardingStore.loginRequested(keyUid, method, data)
        }

        onSkippedBiometricFlow: () => {
            root.skippedBiometricFlow(root.keychain.available)
        }

        Component.onCompleted: {
            root.contentLoaded()
        }

        Component {
            id: convertingKeycardAccountPage

            ConvertKeycardAccountPage {
                convertKeycardAccountState: root.onboardingStore.convertKeycardAccountState
                restartRequired: root.onboardingStore.convertKeycardAccountRestartRequired
                onRestartRequested: {
                    SystemUtils.restartApplication(true)
                }
                onBackToLoginRequested: {
                    d.loginRequestSent = false
                    onboardingLayout.unwindToLoginScreen()
                }
            }
        }
    }
}
