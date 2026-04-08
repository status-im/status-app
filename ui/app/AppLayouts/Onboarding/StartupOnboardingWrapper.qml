import QtQuick
import QtQuick.Controls

import shared.panels

import AppLayouts.Onboarding
import AppLayouts.Onboarding.enums
import AppLayouts.Onboarding.stores
import AppLayouts.Onboarding.pages

import StatusQ.Core.Utils as SQUtils
import StatusQ.Platform

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
            onAccountLoginError: function (error, wrongPassword) {
                onboardingStore.loginRequestSent = false
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
            if (SQUtils.Utils.isMobile) {
                onboardingStore.resetKeycardProgressStates()
            }
        }

        onLoginRequested: function (keyUid, method, data) {
            let selectedProfile = SQUtils.ModelUtils.getByKey(onboardingStore.loginAccountsModel, "keyUid", keyUid)
            if (!selectedProfile) {
                console.error("cannot resolve selected profile")
                return
            }

            onboardingLayout.stack.push(splashScreenV2, { runningProgressAnimation: true }, StackView.Immediate)

            onboardingStore.loginRequestSent = true
            onboardingStore.loginRequested(keyUid, method, data)
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
                convertKeycardAccountState: onboardingStore.convertKeycardAccountState
                onRestartRequested: {
                    SystemUtils.restartApplication()
                }
                onBackToLoginRequested: {
                    onboardingLayout.unwindToLoginScreen()
                }
            }
        }
    }
}