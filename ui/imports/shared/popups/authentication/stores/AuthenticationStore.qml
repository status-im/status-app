import QtQuick

QtObject {
    id: root

    signal keycardAuthSuccess(string encryptionPublicKey)
    signal keycardAuthError(string error)

    readonly property bool ready: d.ready
    readonly property string userProfileKeyUid: userProfile.keyUid

    readonly property QtObject d: QtObject {
        property bool ready: false
        readonly property var mainModuleInst: mainModule
    }

    readonly property Connections authModuleConnections: Connections {
        target: d.mainModuleInst.authenticationModule ?? null

        function onKeycardAuthSuccess(encryptionPublicKey) {
            root.keycardAuthSuccess(encryptionPublicKey)
        }

        function onKeycardAuthError(error) {
            root.keycardAuthError(error)
        }
    }

    readonly property string keycardState: {
        if (!d.mainModuleInst.authenticationModule)
            return ""
        return d.mainModuleInst.authenticationModule.keycardState
    }

    readonly property int remainingPinAttempts: {
        if (!d.mainModuleInst.authenticationModule)
            return -1
        return d.mainModuleInst.authenticationModule.remainingPinAttempts
    }

    readonly property var keyPairForProcessing: {
        if (!d.mainModuleInst.authenticationModule)
            return null
        return d.mainModuleInst.authenticationModule.keyPairForProcessing
    }

    function prepare() {
        d.mainModuleInst.prepareAuthenticationModule()
        d.ready = true
    }

    function teardown() {
        if (!d.mainModuleInst.authenticationModule) {
            console.error("authentication module was not created")
            return
        }
        d.mainModuleInst.authenticationModule.stopKeycardAuthentication()
        d.mainModuleInst.destroyAuthenticationModule()
        d.ready = false
    }

    function isKeypairMigratedToKeycard(keyUid) {
        if (!d.mainModuleInst.authenticationModule) {
            console.error("authentication module was not created")
            return false
        }
        return d.mainModuleInst.authenticationModule.isKeypairMigratedToKeycard(keyUid)
    }

    function verifyPassword(password) {
        if (!d.mainModuleInst.authenticationModule) {
            console.error("authentication module was not created")
            return false
        }
        return d.mainModuleInst.authenticationModule.verifyPassword(password)
    }

    function startKeycardAuthentication(keyUid, pin) {
        if (!d.mainModuleInst.authenticationModule) {
            console.error("authentication module was not created")
            return
        }
        d.mainModuleInst.authenticationModule.startKeycardAuthentication(keyUid, pin)
    }

    function buildKeyPairForProcessing(keyUid) {
        if (!d.mainModuleInst.authenticationModule) {
            console.error("authentication module was not created")
            return
        }
        d.mainModuleInst.authenticationModule.buildKeyPairForProcessing(keyUid)
    }
}
