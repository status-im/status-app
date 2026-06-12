import QtQml

import StatusQ.Core.Utils as StatusQUtils

import shared.popups.keycard_new.stores

BaseKeycardManagementStore {
    id: root

    backend: d.onboardingModuleInst?.keycardModule ?? null

    signal keycardAsyncLoginSuccess(string dataJson)
    signal keycardAsyncLoginError(string error)

    readonly property QtObject d: QtObject {
        readonly property var onboardingModuleInst: onboardingModule
        readonly property var loginAccountsModel: d.onboardingModuleInst?.loginAccountsModel ?? null
    }

    readonly property Connections _onboardingConn: Connections {
        target: backend ?? null

        function onKeycardAsyncLoginSuccess(dataJson) { root.keycardAsyncLoginSuccess(dataJson) }
        function onKeycardAsyncLoginError(error) { root.keycardAsyncLoginError(error) }
    }

    function prepare() {
        d.onboardingModuleInst.prepareKeycardModule()
    }

    function teardown() {
        if (!backend) {
            console.error("onboarding - keycard management module was not created")
            return
        }
        backend.stopKeycardAction()
        d.onboardingModuleInst.destroyKeycardModule()
    }

    function startAsyncLogin(keyUid, pin, generateXPub) {
        if (!backend) {
            console.error("onboarding - keycard management module was not created")
            return
        }
        backend.startAsyncLogin(keyUid, pin, generateXPub)
    }

    function isMnemonicBackedUp() {
        return false
    }

    function getMnemonic() {
        return ""
    }

    function isKnownKeyUid(keyUid) {
        const profile = StatusQUtils.ModelUtils.getByKey(d.loginAccountsModel, "keyUid", keyUid)
        if (!!profile) {
            return true
        }
        return false
    }

    function isKeypairMigratedToColdWallet(keyUid) {
        const profile = StatusQUtils.ModelUtils.getByKey(d.loginAccountsModel, "keyUid", keyUid)
        if (!!profile && profile.keycardPairing.trim().length > 0) {
            return true
        }
        return false
    }
}
