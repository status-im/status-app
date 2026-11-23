import QtQml

import AppLayouts.Profile.stores as ProfileStores

import shared.popups.signing
import shared.popups.signing.stores as SignStores

import utils

SignPopup {
    id: signPopup

    required property SignStores.SigningStore signingStore
    required property ProfileStores.PrivacyStore privacyStore

    property bool succeeded: false
    property string resultSignature: ""

    store: signPopup.signingStore
    getCredentialForStorage: (keyUid, password) => signPopup.privacyStore.getBiometricCredentialForStorage(keyUid, password)
    getStayLoggedInCredentialForStorage: (keyUid, credential) => signPopup.privacyStore.getStayLoggedInCredentialForStorage(keyUid, credential)

    onPasswordProvided: function(password) {
        // in case of signing tx via keycard no password (enc pub key)
        signPopup.signingStore.passwordProvided(signPopup.keyUid, password)
    }

    onSigningSuccess: function(signature) {
        signPopup.resultSignature = signature
        signPopup.succeeded = true
    }

    onClosed: {
        // Because of successive signing requests (in case of sharing multiple addresses) emit the result
        // on the next tick — after this popup is closed and removed from activePopupComponents — that way
        // a chained openSigningPopup isn't blocked by openPopup's same-component dedup guard.
        const reason = signPopup.reason
        const signature = signPopup.succeeded ? signPopup.resultSignature : ""
        const keyUid = signPopup.keyUid
        const path = signPopup.path
        const address = signPopup.address
        Qt.callLater(() => Global.signingResult(reason, signature, keyUid, path, address))
    }
}
