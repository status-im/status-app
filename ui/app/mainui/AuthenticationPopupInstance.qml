import StatusQ

import AppLayouts.Profile.stores as ProfileStores

import shared.popups.authentication
import shared.popups.authentication.stores as AuthStores

import utils

AuthenticationPopup {
    id: root

    required property AuthStores.AuthenticationStore authenticationStore
    required property ProfileStores.PrivacyStore privacyStore

    store: root.authenticationStore
    getCredentialForStorage: (keyUid, password) => root.privacyStore.getBiometricCredentialForStorage(keyUid, password)
    getStayLoggedInCredentialForStorage: (keyUid, credential) => root.privacyStore.getStayLoggedInCredentialForStorage(keyUid, credential)
    biometricsAllowed: reason !== Constants.authenticationReason.syncDevice
                       && reason !== Constants.authenticationReason.disableBiometrics
                       && reason !== Constants.authenticationReason.disableStayLoggedIn
    onAuthenticationSuccess: function(reason, password, pin, keyUid, chatPrivateKey) {
        root.authenticationStore.passwordProvided(keyUid, password)
        Global.authenticationResult(reason, password, pin, keyUid, chatPrivateKey)
    }
}
