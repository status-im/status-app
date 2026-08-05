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

        function onKeycardAsyncLoginSuccess(dataJson: string) : void { root.keycardAsyncLoginSuccess(dataJson) }
        function onKeycardAsyncLoginError(error: string) : void { root.keycardAsyncLoginError(error) }
    }

    function prepare() : void {
        d.onboardingModuleInst.prepareKeycardModule()
    }

    function teardown() : void {
        if (!backend) {
            console.error("onboarding - keycard management module was not created")
            return
        }
        backend.stopKeycardAction()
        d.onboardingModuleInst.destroyKeycardModule()
    }

    function startAsyncLogin(keyUid: string, pin: string, generateXPub: bool, pairingPassword = "") {
        if (!backend) {
            console.error("onboarding - keycard management module was not created")
            return
        }
        backend.startAsyncLogin(keyUid, pin, generateXPub, pairingPassword)
    }

    function isMnemonicBackedUp() : bool {
        return false
    }

    function getMnemonic() : string {
        return ""
    }

    function isKnownKeyUid(keyUid: string) : bool {
        const profile = StatusQUtils.ModelUtils.getByKey(d.loginAccountsModel, "keyUid", keyUid)
        if (!!profile) {
            return true
        }
        return false
    }

    function isKeypairMigratedToColdWallet(keyUid: string) : bool {
        const profile = StatusQUtils.ModelUtils.getByKey(d.loginAccountsModel, "keyUid", keyUid)
        if (!!profile && profile.keycardPairing.trim().length > 0) {
            return true
        }
        return false
    }
}
