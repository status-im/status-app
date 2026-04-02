import QtQuick

import StatusQ

import shared.popups.auth_sign_base 1.0

import utils

import "stores"

PopupBase {
    id: root

    required property string txHash
    required property string path
    required property string address

    required property SigningStore store

    signal signingSuccess(string reason, string signature, string keyUid)

    purpose: PopupBase.Purpose.Signing

    title: qsTr("Sign Transaction")

    btnActionName: qsTr("Sign")
    btnPasswordActionAndUpdateName: qsTr("Update password & sign")
    btnPinActionAndUpdateName: qsTr("Update PIN & sign")

    keycardState: root.store.keycardState
    remainingPinAttempts: root.store.remainingPinAttempts
    userProfileKeyUid: root.store.userProfileKeyUid
    isKeycardKeyPair: root.store.ready && root.store.isKeypairMigratedToKeycard(root.keyUid)
    keyPairForProcessing: root.store.keyPairForProcessing

    performPasswordAction: function(password) {
        const success = root.store.verifyPassword(password)
        if (!success)
            return false

        const signature = root.store.signMessage(root.address, password, root.txHash)
        if (signature === "")
            return false

        root.signingSuccess(root.reason, signature, root.keyUid)
        root.close()
        return true
    }

    performKeycardAction: function(keyUid, pin) {
        root.store.startKeycardSigning(keyUid, pin, root.txHash, root.path)
    }

    closePopupAction: function() {
        root.store.teardown()
    }

    Connections {
        target: root.store

        function onKeycardSignSuccess(r, s, v) {
            root.handleKeycardSuccess()
            const signature = r + s + v.toString(16).padStart(2, '0')
            root.signingSuccess(root.reason, signature, root.keyUid)
            root.close()
        }

        function onKeycardSignError(error) {
            root.handleKeycardError(error)
        }
    }

    Component.onCompleted: {
        root.store.prepare()
        root.store.buildKeyPairForProcessing(root.keyUid)
    }
}
