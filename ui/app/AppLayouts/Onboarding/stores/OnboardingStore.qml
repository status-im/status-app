import QtQml

import StatusQ.Core.Utils as StatusQUtils

import AppLayouts.Onboarding.enums

QtObject {
    id: root

    signal appLoaded()
    signal saveBiometricsRequested(string keyUid, string credential)
    signal deleteBiometricsRequested(string keyUid)

    readonly property QtObject d: StatusQUtils.QObject {
        id: d
        readonly property var onboardingModuleInst: onboardingModule

        Component.onCompleted: {
            d.onboardingModuleInst.appLoaded.connect(root.appLoaded)
            d.onboardingModuleInst.accountLoginError.connect(root.accountLoginError)
            d.onboardingModuleInst.saveBiometricsRequested.connect(root.saveBiometricsRequested)
            d.onboardingModuleInst.deleteBiometricsRequested.connect(root.deleteBiometricsRequested)
        }
    }

    readonly property var loginAccountsModel: d.onboardingModuleInst.loginAccountsModel

    // keycard
    readonly property int keycardState: d.onboardingModuleInst.keycardState // cf. enum Onboarding.KeycardState
    readonly property string keycardUID: d.onboardingModuleInst.keycardUID
    readonly property string keycardKeyUID: d.onboardingModuleInst.keycardKeyUID
    readonly property int convertKeycardAccountState: d.onboardingModuleInst.convertKeycardAccountState // cf. enum Onboarding.ProgressState
    readonly property int keycardRemainingPinAttempts: d.onboardingModuleInst.keycardRemainingPinAttempts
    readonly property int keycardRemainingPukAttempts: d.onboardingModuleInst.keycardRemainingPukAttempts
    readonly property bool keycardStatusAvailable: d.onboardingModuleInst.keycardStatusAvailable
    readonly property int keycardAvailableSlots: d.onboardingModuleInst.keycardAvailableSlots
    readonly property string keycardCardMetadataName: d.onboardingModuleInst.keycardCardMetadataName
    readonly property string keycardCardMetadataWalletAccountsJson: d.onboardingModuleInst.keycardCardMetadataWalletAccountsJson

    function finishOnboardingFlow(flow: int, data: Object) { // -> string
        return d.onboardingModuleInst.finishOnboardingFlow(flow, JSON.stringify(data))
    }

    function loginRequested(keyUid: string, method: int, data: Object) { // -> void
        d.onboardingModuleInst.loginRequested(keyUid, method, JSON.stringify(data))
    }

    function deleteMultiaccountRequested(keyUid: string) {
        d.onboardingModuleInst.requestDeleteMultiaccount(keyUid)
    }

    function cleanupAfterMainTransition() {
        d.onboardingModuleInst.cleanupAfterMainTransition()
    }

    // password
    signal accountLoginError(string error, bool wrongPassword)

    function getPasswordStrengthScore(password: string) { // -> int
        return d.onboardingModuleInst.getPasswordStrengthScore(password, "") // The second argument is username
    }

    // seedphrase/mnemonic
    function validMnemonic(mnemonic: string) : bool {
        return d.onboardingModuleInst.validMnemonic(mnemonic)
    }
    function isMnemonicDuplicate(mnemonic: string) : bool {
        return d.onboardingModuleInst.isMnemonicDuplicate(mnemonic)
    }

    // sync
    readonly property int syncState: d.onboardingModuleInst.syncState // cf. enum Onboarding.ProgressState
    function validateLocalPairingConnectionString(connectionString: string) : bool {
        return d.onboardingModuleInst.validateLocalPairingConnectionString(connectionString)
    }
    function inputConnectionStringForBootstrapping(connectionString: string) {
        d.onboardingModuleInst.inputConnectionStringForBootstrapping(connectionString)
    }
}
