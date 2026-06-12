import QtQuick

QtObject {
    id: root

    required property var keycardNewModule

    readonly property string userProfileKeyUid: userProfile.keyUid
    readonly property string userProfilePubKey: userProfile.pubKey
    readonly property bool migratedToColdWallet: userProfile.migratedToColdWallet

    readonly property var keyPairItem: root.keycardNewModule.keyPairItem

    readonly property QtObject d: QtObject {
        readonly property var mainModuleInst: mainModule
    }

    function isKnownKeyUid(keyUid) {
        return root.keycardNewModule.isKnownKeyUid(keyUid)
    }

    function keycardPairingExists(keycardUid) {
        return root.keycardNewModule.keycardPairingExists(keycardUid)
    }

    function resolveKeyPairItemForKeyUid(keyUid) {
        root.keycardNewModule.resolveKeyPairItemForKeyUid(keyUid)
    }

    function allNonProfileKeyPairsMigratedToColdWallet() {
        return root.keycardNewModule.allNonProfileKeyPairsMigratedToColdWallet()
    }

    function remainingKeypairCapacity() {
        return root.keycardNewModule.remainingKeypairCapacity()
    }

    function remainingAccountCapacity() {
        return root.keycardNewModule.remainingAccountCapacity()
    }
}
