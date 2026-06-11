import QtQuick

import StatusQ

import shared.popups.auth_sign_base 1.0

import utils

import "stores"

PopupBase {
    id: root

    required property AuthenticationStore store

    property bool exportChatKey: false // makes sense to set it only for keycard users (no use case so far where we need it for regular(password) users)

    signal authenticationSuccess(string reason, string password, string pin, string keyUid, string chatPrivateKey)

    title: qsTr("Authenticate")

    btnActionName: qsTr("Authenticate")
    btnPasswordActionAndUpdateName: qsTr("Update password & authenticate")
    btnPinActionAndUpdateName: qsTr("Update PIN & authenticate")

    keycardState: root.store.keycardState
    remainingPinAttempts: root.store.remainingPinAttempts
    userProfileKeyUid: root.store.userProfileKeyUid
    userProfilePublicKey: root.store.userProfilePubKey
    isKeycardKeyPair: root.store.ready && root.store.isKeypairMigratedToColdWallet(root.keyUid)
    keyPairForProcessing: root.store.keyPairForProcessing

    performPasswordAction: function(password) {
        const success = root.store.verifyPassword(password)
        if (success) {
            root.authenticationSuccess(root.reason, password, "", root.keyUid, "")
            root.close()
        }
        return success
    }

    performKeycardAction: function(keyUid, pin) {
        root.store.startKeycardAuthentication(keyUid, pin, root.exportChatKey)
    }

    closePopupAction: function() {
        root.store.teardown()
    }

    Connections {
        target: root.store

        function onKeycardAuthSuccess(encryptionPublicKey, chatPrivateKey) {
            root.handleKeycardSuccess()
            root.authenticationSuccess(root.reason, encryptionPublicKey, "", root.keyUid, chatPrivateKey)
            root.close()
        }

        function onKeycardAuthError(error) {
            root.handleKeycardError(error)
        }
    }

    Component.onCompleted: {
        root.store.prepare()
        root.store.buildKeyPairForProcessing(root.keyUid)
    }
}
