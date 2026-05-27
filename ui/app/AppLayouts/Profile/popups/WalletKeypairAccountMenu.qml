import QtQuick

import StatusQ.Core.Theme
import StatusQ.Popups

import utils

StatusMenu {
    id: root

    property var keyPair
    property bool hasPairedDevices: false

    signal runExportQrFlow()
    signal runImportViaQrFlow()
    signal runImportViaSeedPhraseFlow()
    signal runImportViaPrivateKeyFlow()
    signal runRenameKeypairFlow()
    signal runRemoveKeypairFlow()
    signal runMoveKeypairToKeycardFlow()
    signal runStopUsingKeycardFlow()

    StatusAction {
        text: enabled? qsTr("Show encrypted QR on device") : ""
        enabled: root.hasPairedDevices &&
                 !!root.keyPair &&
                 root.keyPair.pairType !== Constants.keypair.type.profile &&
                 !root.keyPair.migratedToColdWallet &&
                 root.keyPair.operability !== Constants.keypair.operability.nonOperable
        icon.name: "qr"
        icon.color: Theme.palette.primaryColor1
        onTriggered: {
            root.runExportQrFlow()
        }
    }

    StatusAction {
        text: enabled? root.keyPair.migratedToColdWallet? qsTr("Stop using Keycard") : qsTr("Move key pair to a Keycard") : ""
        enabled: !!root.keyPair && root.keyPair.pairType !== Constants.keypair.type.privateKeyImport
        icon.name: !!root.keyPair && root.keyPair.migratedToColdWallet? "keycard-crossed" : "keycard"
        icon.color: Theme.palette.primaryColor1
        onTriggered: {
            if (root.keyPair.migratedToColdWallet)
                root.runStopUsingKeycardFlow()
            else
                root.runMoveKeypairToKeycardFlow()
        }
    }

    StatusAction {
        text: enabled? qsTr("Import key pair from device via encrypted QR") : ""
        enabled: root.hasPairedDevices &&
                 !!root.keyPair &&
                 root.keyPair.pairType !== Constants.keypair.type.profile &&
                 !root.keyPair.migratedToColdWallet &&
                 root.keyPair.operability === Constants.keypair.operability.nonOperable
        icon.name: "qr-scan"
        icon.color: Theme.palette.primaryColor1
        onTriggered: {
            root.runImportViaQrFlow()
        }
    }

    StatusAction {
        text: enabled? root.keyPair.pairType === Constants.keypair.type.privateKeyImport? qsTr("Import via entering private key") : qsTr("Import via entering recovery phrase") : ""
        enabled: !!root.keyPair &&
                 !root.keyPair.migratedToColdWallet &&
                 root.keyPair.operability === Constants.keypair.operability.nonOperable &&
                 (root.keyPair.pairType === Constants.keypair.type.seedImport ||
                  root.keyPair.pairType === Constants.keypair.type.privateKeyImport)
        icon.name: enabled? root.keyPair.pairType === Constants.keypair.type.privateKeyImport? "objects" : "key_pair_seed_phrase" : ""
        icon.color: Theme.palette.primaryColor1
        onTriggered: {
            if (root.keyPair.pairType === Constants.keypair.type.privateKeyImport)
                root.runImportViaPrivateKeyFlow()
            else
                root.runImportViaSeedPhraseFlow()
        }
    }

    StatusAction {
        text: enabled? qsTr("Rename key pair") : ""
        objectName: "renameKeypairMenuItem"
        enabled: !!root.keyPair &&
                 root.keyPair.pairType !== Constants.keypair.type.profile
        icon.name: "edit"
        icon.color: Theme.palette.primaryColor1
        onTriggered: {
            root.runRenameKeypairFlow()
        }
    }

    StatusMenuSeparator {
        visible: !!root.keyPair &&
                 root.keyPair.pairType !== Constants.keypair.type.profile
    }

    StatusAction {
        text: enabled? qsTr("Remove key pair and derived accounts") : ""
        enabled: !!root.keyPair &&
                 root.keyPair.pairType !== Constants.keypair.type.profile
        type: StatusAction.Type.Danger
        icon.name: "delete"
        icon.color: Theme.palette.dangerColor1
        onTriggered: {
            root.runRemoveKeypairFlow()
        }
    }
}
