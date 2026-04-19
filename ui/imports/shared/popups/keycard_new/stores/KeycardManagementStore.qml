import QtQuick

QtObject {
    id: root

    signal keycardGetMetadataSuccess()
    signal keycardGetMetadataError(string error)

    signal keycardFactoryResetSuccess()
    signal keycardFactoryResetError(string error)

    signal keycardImportKeyPairSuccess()
    signal keycardImportKeyPairError(string error)

    signal keycardMoveKeyPairSuccess()
    signal keycardMoveKeyPairError(string error)

    readonly property bool ready: d.ready
    readonly property string userProfileKeyUid: userProfile.keyUid

    readonly property var keypairsModel: d.mainModuleInst.keycardManagementModule
                                         ? d.mainModuleInst.keycardManagementModule.keyPairModel
                                         : null

    readonly property QtObject d: QtObject {
        property bool ready: false
        readonly property var mainModuleInst: mainModule
    }

    readonly property Connections keycardManagementModuleConnections: Connections {
        target: d.mainModuleInst.keycardManagementModule ?? null

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

    function startMigratingNonProfileKeypairToKeycard(password, pin, seedPhrase, metadataName, metadataAccounts) {
        if (!d.mainModuleInst.keycardManagementModule) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.keycardManagementModule.startMigratingNonProfileKeypairToKeycard(password, pin, seedPhrase, metadataName, metadataAccounts)
    }
}
