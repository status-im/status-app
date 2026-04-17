import QtQuick

QtObject {
    id: root

    signal keycardSignSuccess(string r, string s, int v)
    signal keycardSignError(string error)

    readonly property bool ready: d.ready
    readonly property string userProfileKeyUid: userProfile.keyUid
    readonly property string userProfilePubKey: userProfile.pubKey

    readonly property QtObject d: QtObject {
        property bool ready: false
        readonly property var mainModuleInst: mainModule
    }

    readonly property Connections signingModuleConnections: Connections {
        target: d.mainModuleInst.signingModule ?? null

        function onKeycardSignSuccess(r, s, v) {
            root.keycardSignSuccess(r, s, v)
        }

        function onKeycardSignError(error) {
            root.keycardSignError(error)
        }
    }

    readonly property string keycardState: {
        if (!d.mainModuleInst.signingModule)
            return ""
        return d.mainModuleInst.signingModule.keycardState
    }

    readonly property int remainingPinAttempts: {
        if (!d.mainModuleInst.signingModule)
            return -1
        return d.mainModuleInst.signingModule.remainingPinAttempts
    }

    readonly property var keyPairForProcessing: {
        if (!d.mainModuleInst.signingModule)
            return null
        return d.mainModuleInst.signingModule.keyPairForProcessing
    }

    function prepare() {
        d.mainModuleInst.prepareSigningModule()
        d.ready = true
    }

    function teardown() {
        if (!d.mainModuleInst.signingModule) {
            console.error("signing module was not created")
            return
        }
        d.mainModuleInst.signingModule.stopKeycardSigning()
        d.mainModuleInst.destroySigningModule()
        d.ready = false
    }

    function isKeypairMigratedToKeycard(keyUid) {
        if (!d.mainModuleInst.signingModule) {
            console.error("signing module was not created")
            return false
        }
        return d.mainModuleInst.signingModule.isKeypairMigratedToKeycard(keyUid)
    }

    function verifyPassword(password) {
        if (!d.mainModuleInst.signingModule) {
            console.error("signing module was not created")
            return false
        }
        return d.mainModuleInst.signingModule.verifyPassword(password)
    }

    function signMessage(address, password, txHash) {
        if (!d.mainModuleInst.signingModule) {
            console.error("signing module was not created")
            return ""
        }
        return d.mainModuleInst.signingModule.signMessage(address, password, txHash)
    }

    function startKeycardSigning(keyUid, pin, txHash, path) {
        if (!d.mainModuleInst.signingModule) {
            console.error("signing module was not created")
            return
        }
        d.mainModuleInst.signingModule.startKeycardSigning(keyUid, pin, txHash, path)
    }

    function buildKeyPairForProcessing(keyUid) {
        if (!d.mainModuleInst.signingModule) {
            console.error("signing module was not created")
            return
        }
        d.mainModuleInst.signingModule.buildKeyPairForProcessing(keyUid)
    }
}
