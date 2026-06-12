import QtQml

QtObject {
    id: root

    required property var backend // refers to the Nim module to support keycard management popup for different needs

    readonly property string keycardState: backend ? backend.keycardState : ""
    readonly property bool keycardStatusAvailable: backend ? backend.keycardStatusAvailable : false
    readonly property int remainingPinAttempts: backend ? backend.remainingPinAttempts : -1
    readonly property int remainingPukAttempts: backend ? backend.remainingPukAttempts : -1
    readonly property int availableSlots: backend ? backend.availableSlots : -1
    readonly property string keycardUid: backend ? backend.keycardUid : ""
    readonly property string keyUid: backend ? backend.keyUid : ""
    readonly property string cardMetadataName: backend ? backend.cardMetadataName : ""
    readonly property string cardMetadataWalletAccountsJson: backend ? backend.cardMetadataWalletAccountsJson : "[]"

    // popup lifecycle
    function prepare() {
        console.error("prepare not implemented")
    }
    function teardown() {
        console.error("teardown not implemented")
    }

    // common function calls
    function startGetMetadata(pin) {
        if (!backend)
            return
        backend.startGetMetadata(pin)
    }

    function startFactoryReset(keycardUid) {
        if (!backend)
            return
        backend.startFactoryReset(keycardUid)
    }

    function startUnblockKeycardUsingPuk(newPin, puk) {
        if (!backend)
            return
        backend.startUnblockKeycardUsingPuk(newPin, puk)
    }

    function startUnblockKeycardUsingRecoveryPhrase(newPin, seedPhrase, metadataName, metadataAccountsJson) {
        if (!backend)
            return
        backend.startUnblockKeycardUsingRecoveryPhrase(newPin, seedPhrase, metadataName, metadataAccountsJson)
    }

    function startImportingKeyPair(pin, seedPhrase, metadataName, metadataAccounts) {
        if (!backend)
            return
        backend.startImportingKeyPair(pin, seedPhrase, metadataName, metadataAccounts)
    }

    function getKeyUidForSeedPhrase(seedPhrase) {
        if (!backend)
            return ""
        return backend.getKeyUidForSeedPhrase(seedPhrase)
    }

    function generateMnemonic() {
        if (!backend)
            return ""
        return backend.generateMnemonic()
    }

    // functions to override
    function signOutAndQuit() {
        console.error("signOutAndQuit not implemented")
    }

    function prepareKeyPairModel() {
        console.error("prepareKeyPairModel not implemented")
    }

    function isKnownKeyUid(keyUid) {
        console.error("isKnownKeyUid not implemented")
    }

    function isKeypairMigratedToColdWallet(keyUid) {
        console.error("isKeypairMigratedToColdWallet not implemented")
    }

    function getKeyPairNameForKeyUid(keyUid) {
        console.error("getKeyPairNameForKeyUid not implemented")
    }

    function getKeyPairAccountPathsJsonForKeyUid(keyUid) {
        console.error("getKeyPairAccountPathsJsonForKeyUid not implemented")
    }

    function isMnemonicBackedUp() {
        console.error("isMnemonicBackedUp not implemented")
    }

    function getMnemonic() {
        console.error("getMnemonic not implemented")
    }

    function resolveKeyPairItemForKeyUid(keyUid) {
        console.error("resolveKeyPairItemForKeyUid not implemented")
    }

    function remainingKeypairCapacity() {
        console.error("remainingKeypairCapacity not implemented")
    }

    function remainingAccountCapacity() {
        console.error("remainingAccountCapacity not implemented")
    }

    // common signals
    signal keycardGetMetadataSuccess()
    signal keycardGetMetadataError(string error)

    signal keycardFactoryResetSuccess()
    signal keycardFactoryResetError(string error)

    signal keycardUnblockSuccess()
    signal keycardUnblockError(string error)

    signal keycardImportKeyPairSuccess()
    signal keycardImportKeyPairError(string error)

    readonly property Connections _baseConn: Connections {
        target: root.backend ?? null

        function onKeycardGetMetadataSuccess() { root.keycardGetMetadataSuccess() }
        function onKeycardGetMetadataError(error) { root.keycardGetMetadataError(error) }

        function onKeycardFactoryResetSuccess() { root.keycardFactoryResetSuccess() }
        function onKeycardFactoryResetError(error) { root.keycardFactoryResetError(error) }

        function onKeycardUnblockSuccess() { root.keycardUnblockSuccess() }
        function onKeycardUnblockError(error) { root.keycardUnblockError(error) }

        function onKeycardImportKeyPairSuccess() { root.keycardImportKeyPairSuccess() }
        function onKeycardImportKeyPairError(error) { root.keycardImportKeyPairError(error) }
    }
}
