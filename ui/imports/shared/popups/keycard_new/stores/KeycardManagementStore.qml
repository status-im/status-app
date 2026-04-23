import QtQuick

QtObject {
    id: root

    signal keycardInteractionSuccessfullyCompleted()

    signal keycardGetMetadataSuccess()
    signal keycardGetMetadataError(string error)

    signal keycardFactoryResetSuccess()
    signal keycardFactoryResetError(string error)

    signal keycardImportKeyPairSuccess()
    signal keycardImportKeyPairError(string error)

    signal keycardMoveKeyPairSuccess()
    signal keycardMoveKeyPairError(string error)

    signal keycardMoveProfileKeyPairSuccess()
    signal keycardMoveProfileKeyPairError(string error)

    signal keycardAddKeyPairSuccess()
    signal keycardAddKeyPairError(string error)

    signal stopUsingKeycardForKeyPairSuccess()
    signal stopUsingKeycardForKeyPairError(string error)

    signal stopUsingKeycardForProfileKeyPairSuccess()
    signal stopUsingKeycardForProfileKeyPairError(string error)

    signal keycardChangePinSuccess()
    signal keycardChangePinError(string error)

    readonly property bool ready: d.ready

    readonly property string userProfileKeyUid: userProfile.keyUid
    readonly property string userProfilePubKey: userProfile.pubKey

    readonly property var keypairsModel: d.mainModuleInst.keycardManagementModule
                                         ? d.mainModuleInst.keycardManagementModule.keyPairModel
                                         : null

    readonly property var keyPairItem: d.mainModuleInst.keycardManagementModule
                                       ? d.mainModuleInst.keycardManagementModule.keyPairItem
                                       : null

    readonly property QtObject d: QtObject {
        property bool ready: false
        readonly property var mainModuleInst: mainModule
    }

    readonly property Connections keycardManagementModuleConnections: Connections {
        target: d.mainModuleInst.keycardManagementModule ?? null

        function onKeycardInteractionSuccessfullyCompleted() {
            root.keycardInteractionSuccessfullyCompleted()
        }

        function onKeycardGetMetadataSuccess() {
            root.keycardGetMetadataSuccess()
        }

        function onKeycardGetMetadataError(error) {
            root.keycardGetMetadataError(error)
        }

        function onKeycardFactoryResetSuccess() {
            root.keycardFactoryResetSuccess()
        }

        function onKeycardFactoryResetError(error) {
            root.keycardFactoryResetError(error)
        }

        function onKeycardImportKeyPairSuccess() {
            root.keycardImportKeyPairSuccess()
        }

        function onKeycardImportKeyPairError(error) {
            root.keycardImportKeyPairError(error)
        }

        function onKeycardMoveKeyPairSuccess() {
            root.keycardMoveKeyPairSuccess()
        }

        function onKeycardMoveKeyPairError(error) {
            root.keycardMoveKeyPairError(error)
        }

        function onKeycardMoveProfileKeyPairSuccess() {
            root.keycardMoveProfileKeyPairSuccess()
        }

        function onKeycardMoveProfileKeyPairError(error) {
            root.keycardMoveProfileKeyPairError(error)
        }

        function onKeycardAddKeyPairSuccess() {
            root.keycardAddKeyPairSuccess()
        }

        function onKeycardAddKeyPairError(error) {
            root.keycardAddKeyPairError(error)
        }

        function onStopUsingKeycardForKeyPairSuccess() {
            root.stopUsingKeycardForKeyPairSuccess()
        }

        function onStopUsingKeycardForKeyPairError(error) {
            root.stopUsingKeycardForKeyPairError(error)
        }

        function onStopUsingKeycardForProfileKeyPairSuccess() {
            root.stopUsingKeycardForProfileKeyPairSuccess()
        }

        function onStopUsingKeycardForProfileKeyPairError(error) {
            root.stopUsingKeycardForProfileKeyPairError(error)
        }

        function onKeycardChangePinSuccess() {
            root.keycardChangePinSuccess()
        }

        function onKeycardChangePinError(error) {
            root.keycardChangePinError(error)
        }
    }

    readonly property string keycardState: {
        if (!d.mainModuleInst.keycardManagementModule)
            return ""
        return d.mainModuleInst.keycardManagementModule.keycardState
    }

    readonly property int remainingPinAttempts: {
        if (!d.mainModuleInst.keycardManagementModule)
            return -1
        return d.mainModuleInst.keycardManagementModule.remainingPinAttempts
    }

    readonly property int remainingPukAttempts: {
        if (!d.mainModuleInst.keycardManagementModule)
            return -1
        return d.mainModuleInst.keycardManagementModule.remainingPukAttempts
    }

    readonly property int availableSlots: {
        if (!d.mainModuleInst.keycardManagementModule)
            return -1
        return d.mainModuleInst.keycardManagementModule.availableSlots
    }

    readonly property string keycardUid: {
        if (!d.mainModuleInst.keycardManagementModule)
            return ""
        return d.mainModuleInst.keycardManagementModule.keycardUid
    }

    readonly property string keyUid: {
        if (!d.mainModuleInst.keycardManagementModule)
            return ""
        return d.mainModuleInst.keycardManagementModule.keyUid
    }

    readonly property string cardMetadataName: {
        if (!d.mainModuleInst.keycardManagementModule)
            return ""
        return d.mainModuleInst.keycardManagementModule.cardMetadataName
    }

    readonly property string cardMetadataWalletAccountsJson: {
        if (!d.mainModuleInst.keycardManagementModule)
            return "[]"
        return d.mainModuleInst.keycardManagementModule.cardMetadataWalletAccountsJson
    }

    function prepare() {
        d.mainModuleInst.prepareKeycardManagementModule()
        d.ready = true
    }

    function signOutAndQuit() {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.signOutAndQuit()
    }

    function prepareKeyPairModel() {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.populateKeyPairModel()
    }

    function teardown() {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.stopKeycardAction()
        d.mainModuleInst.destroyKeycardManagementModule()
        d.ready = false
    }

    function startGetMetadata(pin) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startGetMetadata(pin)
    }

    function startFactoryReset(keycardUid) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startFactoryReset(keycardUid)
    }

    function getKeyUidForSeedPhrase(seedPhrase) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return ""
        }
        return d.mainModuleInst.keycardManagementModule.getKeyUidForSeedPhrase(seedPhrase)
    }

    function isKnownKeyUid(keyUid) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return false
        }
        return d.mainModuleInst.keycardManagementModule.isKnownKeyUid(keyUid)
    }

    function isKeyPairMigratedToKeycard(keyUid) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return false
        }
        return d.mainModuleInst.keycardManagementModule.isKeyPairMigratedToKeycard(keyUid)
    }

    function getKeyPairNameForKeyUid(keyUid) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return ""
        }
        return d.mainModuleInst.keycardManagementModule.getKeyPairNameForKeyUid(keyUid)
    }

    function getKeyPairAccountPathsJsonForKeyUid(keyUid) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return "[]"
        }
        return d.mainModuleInst.keycardManagementModule.getKeyPairAccountPathsJsonForKeyUid(keyUid)
    }

    function startImportingKeyPair(pin, seedPhrase, metadataName, metadataAccounts) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startImportingKeyPair(pin, seedPhrase, metadataName, metadataAccounts)
    }

    function generateMnemonic() {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return ""
        }
        return d.mainModuleInst.keycardManagementModule.generateMnemonic()
    }

    function startMigratingNonProfileKeypairToKeycard(password, pin, seedPhrase) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startMigratingNonProfileKeypairToKeycard(password, pin, seedPhrase)
    }

    function isMnemonicBackedUp() {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return true
        }
        return d.mainModuleInst.keycardManagementModule.isMnemonicBackedUp()
    }

    function getMnemonic() {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return ""
        }
        return d.mainModuleInst.keycardManagementModule.getMnemonic()
    }

    function startMigratingProfileKeypairToKeycard(password, pin, seedPhrase) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startMigratingProfileKeypairToKeycard(password, pin, seedPhrase)
    }

    function startAddingKeyPairToStatusFromKeycard(pin, keyUid, metadataName, metadataAccounts) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startAddingKeyPairToStatusFromKeycard(pin, keyUid, metadataName, metadataAccounts)
    }

    function resolveKeyPairItemForKeyUid(keyUid) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.resolveKeyPairItemForKeyUid(keyUid)
    }

    function startStopUsingKeycardForKeyPair(keyUid, seedPhrase, newPassword) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startStopUsingKeycardForKeyPair(keyUid, seedPhrase, newPassword)
    }

    function startStopUsingKeycardForProfileKeyPair(seedPhrase, newPassword) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startStopUsingKeycardForProfileKeyPair(seedPhrase, newPassword)
    }

    function startChangeKeycardPIN(currentPin, newPin) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startChangeKeycardPIN(currentPin, newPin)
    }

    function remainingKeypairCapacity() {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return 0
        }
        return d.mainModuleInst.keycardManagementModule.remainingKeypairCapacity()
    }

    function remainingAccountCapacity() {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return 0
        }
        return d.mainModuleInst.keycardManagementModule.remainingAccountCapacity()
    }
}
