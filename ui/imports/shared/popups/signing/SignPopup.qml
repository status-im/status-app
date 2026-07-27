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

    signal passwordProvided(string password)
    signal signingSuccess(string signature)

    purpose: PopupBase.Purpose.Signing

    title: {
        if (root.store.ready && root.reason === Constants.signingReason.communitiesSignSharedAddresses) {
            const accName = root.store.getAccountNameByAddress(root.address)
            return qsTr("Sign community request with %1").arg(accName)
        }

        return qsTr("Sign Transaction")
    }

    btnActionName: qsTr("Sign")
    btnPasswordActionAndUpdateName: qsTr("Update password & sign")
    btnPinActionAndUpdateName: qsTr("Update PIN & sign")

    keycardState: root.store.keycardState
    remainingPinAttempts: root.store.remainingPinAttempts
    userProfileKeyUid: root.store.userProfileKeyUid
    userProfilePublicKey: root.store.userProfilePubKey
    userProfileMigratedToColdWallet: root.store.userProfileMigratedToColdWallet
    isKeycardKeyPair: root.store.ready && root.store.isKeypairMigratedToColdWallet(root.keyUid)
    keyPairForProcessing: root.store.keyPairForProcessing

    externalAuthorization: !root.isKeycardKeyPair && root.userProfileMigratedToColdWallet

    performPasswordAction: function(password) {
        const success = root.store.verifyPassword(password)
        if (!success)
            return false

        root.passwordProvided(password) // in case of signing tx via keycard no password (enc pub key)

        const signature = root.store.signMessage(root.address, password, root.txHash)
        if (signature === "")
            return false

        root.signingSuccess(signature)
        root.close()
        return true
    }

    performKeycardAction: function(keyUid, pin) {
        root.store.startKeycardSigning(keyUid, pin, root.txHash, root.path)
    }

    onAuthorizeRequested: {
        Global.openAuthenticationPopup(Constants.authenticationReason.signing, root.store.userProfileKeyUid, false)
    }

    closePopupAction: function() {
        root.store.teardown()
    }

    Connections {
        target: root.store

        function onKeycardSignSuccess(signature) {
            root.handleKeycardSuccess()
            root.signingSuccess(signature)
            root.close()
        }

        function onKeycardSignError(error) {
            root.handleKeycardError(error)
        }
    }

    Connections {
        target: Global
        enabled: root.externalAuthorization

        function onAuthenticationResult(reason, password, pin, keyUid, chatPrivateKey) {
            if (reason !== Constants.authenticationReason.signing)
                return
            if (!password)
                return

            root.passwordProvided(password) // in case of signing tx via keycard no password (enc pub key)

            const signature = root.store.signMessage(root.address, password, root.txHash)
            if (signature === "") {
                Global.displayToastMessage(qsTr("Failed to sign with the authorized credentials"), "", "warning",
                                           false, Constants.ephemeralNotificationType.danger, "")
                return
            }
            root.signingSuccess(signature)
            root.close()
        }
    }

    Component.onCompleted: {
        root.store.prepare()
        root.store.buildKeyPairForProcessing(root.keyUid)
    }
}
