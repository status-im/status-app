import QtCore
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml.Models
import QtQml
import StatusQ
import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import AppLayouts.stores as AppLayoutStores
import AppLayouts.Chat.popups
import AppLayouts.Profile.popups
import AppLayouts.Profile.stores as ProfileStores
import AppLayouts.Communities.popups
import AppLayouts.Communities.helpers
import AppLayouts.Wallet.popups.buy
import AppLayouts.Wallet.popups
import AppLayouts.Wallet.helpers
import AppLayouts.Communities.stores
import AppLayouts.Profile.helpers
import AppLayouts.Wallet.services.dapps
import mainui.popups
import AppLayouts.Wallet.stores as WalletStores
import AppLayouts.Chat.stores as ChatStores
import AppLayouts.stores.Messaging as MessagingStores
import AppLayouts.stores.Messaging.Community as CommunityStores
import shared.popups
import shared.popups.authentication
import shared.popups.authentication.stores 1.0 as AuthStores
import shared.popups.signing
import shared.popups.signing.stores 1.0 as SignStores
import shared.popups.keycard_new
import shared.popups.keycard_new.stores 1.0 as KeycardMgmtStores
import shared.status
import shared.stores
import shared.views
import shared.views.profile
import utils

SignPopup {
    id: signPopup

    required property Popups host

    property bool succeeded: false
    property string resultSignature: ""

    store: signPopup.host.signingStore
    keychain: signPopup.host.keychain
    secureStorage: signPopup.host.secureStorage
    getCredentialForStorage: (keyUid, password) => signPopup.host.privacyStore.getBiometricCredentialForStorage(keyUid, password)
    getStayLoggedInCredentialForStorage: (keyUid, credential) => signPopup.host.privacyStore.getStayLoggedInCredentialForStorage(keyUid, credential)

    onPasswordProvided: function(password) {
        // in case of signing tx via keycard no password (enc pub key)
        signPopup.host.signingStore.passwordProvided(signPopup.keyUid, password)
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
        destroy()
    }
}
