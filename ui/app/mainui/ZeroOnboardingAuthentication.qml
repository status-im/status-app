import QtQuick

import shared.popups.authentication.stores as AuthStores
import shared.popups.signing.stores as SignStores

// Stands in for the password prompts until the profile has a password
QtObject {
    id: root

    required property AuthStores.AuthenticationStore authenticationStore
    required property SignStores.SigningStore signingStore

    signal passwordRequired(var onSuccess, var onCancel)
    signal authenticated(string reason, string password, string keyUid)
    // Empty signature when cancelled or failed
    signal signed(string reason, string signature, string keyUid, string path, string address)
    signal signingFailed()

    // false for a Keycard key pair: its PIN, asked by the regular prompt, unlocks it.
    // A cancel emits nothing, as closing the authentication popup does
    function authenticate(reason: string, keyUid: string) : bool {
        if (d.isOnKeycard(keyUid))
            return false
        root.passwordRequired((password) => {
            root.authenticationStore.prepare()
            root.authenticationStore.passwordProvided(keyUid, password)
            root.authenticated(reason, password, keyUid)
            root.authenticationStore.teardown()
        }, null)
        return true
    }

    // false for a Keycard key pair, as for authenticate()
    function sign(reason: string, keyUid: string, txHash: string, path: string, address: string) : bool {
        if (d.isOnKeycard(keyUid))
            return false
        const emitSigned = (signature) => Qt.callLater(() => root.signed(reason, signature, keyUid, path, address))
        root.passwordRequired((password) => {
            root.signingStore.prepare()
            root.signingStore.passwordProvided(keyUid, password)
            const signature = root.signingStore.signMessage(address, password, txHash)
            root.signingStore.teardown()
            if (signature === "")
                root.signingFailed()
            emitSigned(signature)
        }, () => emitSigned(""))
        return true
    }

    readonly property QtObject _d: QtObject {
        id: d

        // Leaves a module that an open prompt is using in place
        function isOnKeycard(keyUid: string) : bool {
            const store = root.authenticationStore
            const prepared = store.ready
            if (!prepared)
                store.prepare()
            const onKeycard = store.isKeypairMigratedToColdWallet(keyUid)
            if (!prepared)
                store.teardown()
            return onKeycard
        }
    }
}
