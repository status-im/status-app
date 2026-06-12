import QtQuick

BaseKeycardManagementStore {
    id: root

    backend: d.mainModuleInst.keycardManagementModule ?? null

    readonly property bool ready: d.ready

    readonly property string userProfileKeyUid: userProfile.keyUid
    readonly property string userProfilePubKey: userProfile.pubKey

    readonly property var keypairsModel: backend ? backend.keyPairModel : null
    readonly property var keyPairItem: backend ? backend.keyPairItem : null

    signal keycardInteractionSuccessfullyCompleted()

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

    signal keycardChangePukSuccess()
    signal keycardChangePukError(string error)

    signal keycardRenameSuccess()
    signal keycardRenameError(string error)

    readonly property QtObject d: QtObject {
        property bool ready: false
        readonly property var mainModuleInst: mainModule
    }

    readonly property Connections _settingsConn: Connections {
        target: root.backend ?? null

        function onKeycardInteractionSuccessfullyCompleted() {
            root.keycardInteractionSuccessfullyCompleted()
        }

        function onKeycardMoveKeyPairSuccess() { root.keycardMoveKeyPairSuccess() }
        function onKeycardMoveKeyPairError(error) { root.keycardMoveKeyPairError(error) }

        function onKeycardMoveProfileKeyPairSuccess() { root.keycardMoveProfileKeyPairSuccess() }
        function onKeycardMoveProfileKeyPairError(error) { root.keycardMoveProfileKeyPairError(error) }

        function onKeycardAddKeyPairSuccess() { root.keycardAddKeyPairSuccess() }
        function onKeycardAddKeyPairError(error) { root.keycardAddKeyPairError(error) }

        function onStopUsingKeycardForKeyPairSuccess() { root.stopUsingKeycardForKeyPairSuccess() }
        function onStopUsingKeycardForKeyPairError(error) { root.stopUsingKeycardForKeyPairError(error) }

        function onStopUsingKeycardForProfileKeyPairSuccess() { root.stopUsingKeycardForProfileKeyPairSuccess() }
        function onStopUsingKeycardForProfileKeyPairError(error) { root.stopUsingKeycardForProfileKeyPairError(error) }

        function onKeycardChangePinSuccess() { root.keycardChangePinSuccess() }
        function onKeycardChangePinError(error) { root.keycardChangePinError(error) }

        function onKeycardChangePukSuccess() { root.keycardChangePukSuccess() }
        function onKeycardChangePukError(error) { root.keycardChangePukError(error) }

        function onKeycardRenameSuccess() { root.keycardRenameSuccess() }
        function onKeycardRenameError(error) { root.keycardRenameError(error) }
    }

    function prepare() {
        d.mainModuleInst.prepareKeycardManagementModule()
        d.ready = true
    }

    function teardown() {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        backend.stopKeycardAction()
        d.mainModuleInst.destroyKeycardManagementModule()
        d.ready = false
    }

    function signOutAndQuit() {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        d.mainModuleInst.signOutAndQuit()
    }

    function prepareKeyPairModel() {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        backend.populateKeyPairModel()
    }

    function isKnownKeyUid(keyUid) {
        if (!backend) {
            console.error("keycard management module was not created")
            return false
        }
        return backend.isKnownKeyUid(keyUid)
    }

    function isKeypairMigratedToColdWallet(keyUid) {
        if (!backend) {
            console.error("keycard management module was not created")
            return false
        }
        return backend.isKeypairMigratedToColdWallet(keyUid)
    }

    function getKeyPairNameForKeyUid(keyUid) {
        if (!backend) {
            console.error("keycard management module was not created")
            return ""
        }
        return backend.getKeyPairNameForKeyUid(keyUid)
    }

    function getKeyPairAccountPathsJsonForKeyUid(keyUid) {
        if (!backend) {
            console.error("keycard management module was not created")
            return "[]"
        }
        return backend.getKeyPairAccountPathsJsonForKeyUid(keyUid)
    }

    function startMigratingNonProfileKeypairToKeycard(password, pin, seedPhrase) {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        backend.startMigratingNonProfileKeypairToKeycard(password, pin, seedPhrase)
    }

    function isMnemonicBackedUp() {
        if (!backend) {
            console.error("keycard management module was not created")
            return true
        }
        return backend.isMnemonicBackedUp()
    }

    function getMnemonic() {
        if (!backend) {
            console.error("keycard management module was not created")
            return ""
        }
        return backend.getMnemonic()
    }

    function startMigratingProfileKeypairToKeycard(password, pin, seedPhrase) {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        backend.startMigratingProfileKeypairToKeycard(password, pin, seedPhrase)
    }

    function startAddingKeyPairToStatusFromKeycard(pin, keyUid, metadataName, metadataAccounts) {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        backend.startAddingKeyPairToStatusFromKeycard(pin, keyUid, metadataName, metadataAccounts)
    }

    function resolveKeyPairItemForKeyUid(keyUid) {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        backend.resolveKeyPairItemForKeyUid(keyUid)
    }

    function startStopUsingKeycardForKeyPair(keyUid, seedPhrase, newPassword) {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        backend.startStopUsingKeycardForKeyPair(keyUid, seedPhrase, newPassword)
    }

    function startStopUsingKeycardForProfileKeyPair(seedPhrase, newPassword) {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        backend.startStopUsingKeycardForProfileKeyPair(seedPhrase, newPassword)
    }

    function startChangeKeycardPIN(currentPin, newPin) {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        backend.startChangeKeycardPIN(currentPin, newPin)
    }

    function startChangeKeycardPUK(currentPin, newPuk) {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        backend.startChangeKeycardPUK(currentPin, newPuk)
    }

    function startRenameKeycard(currentPin, newName, metadataAccountsJson) {
        if (!backend) {
            console.error("keycard management module was not created")
            return
        }
        backend.startRenameKeycard(currentPin, newName, metadataAccountsJson)
    }

    function remainingKeypairCapacity() {
        if (!backend) {
            console.error("keycard management module was not created")
            return 0
        }
        return backend.remainingKeypairCapacity()
    }

    function remainingAccountCapacity() {
        if (!backend) {
            console.error("keycard management module was not created")
            return 0
        }
        return backend.remainingAccountCapacity()
    }
}
