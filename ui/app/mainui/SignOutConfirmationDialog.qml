import QtQuick

import shared.popups
import utils

import StatusQ

ConfirmationDialog {
    id: root

    objectName: "SignOutConfirmationDialog"

    required property SecureStorage secureStorage
    required property string keyUid

    // Store exposing setAutoLoginSuppressed(keyUid, value) -> bool (PrivacyStore in the
    // app) — an explicit dependency instead of a hidden context-property global.
    required property var privacyStore

    signal signOutRequested()

    confirmButtonObjectName: "signOutConfirmation"
    headerSettings.title: qsTr("Sign out")
    confirmationText: qsTr("Make sure you have your account password and recovery phrase stored. Without them you can lock yourself out of your account and lose funds.")
    confirmButtonLabel: qsTr("Sign out & Quit")

    onConfirmButtonClicked: {
        // Sign-out clears the auto-login credential first (startup trusts credential
        // presence). The per-account preference deliberately survives (the next explicit
        // login re-stores a fresh credential), and the biometric item is intentionally
        // untouched. NotSupported counts as verified: it only ever comes from the stub
        // backend (no implementation on this platform), where no build could ever have
        // stored a credential; a store THIS process merely cannot reach (e.g. an
        // unsigned dev build) reports Unavailable and is handled below.
        const status = root.secureStorage.deleteCredential(root.keyUid)
        const deletionVerified = status === SecureStorage.StatusSuccess
                              || status === SecureStorage.StatusNotFound
                              || status === SecureStorage.StatusNotSupported
        if (!deletionVerified) {
            // The credential may still exist (transient failure, timeout, locked
            // keyring, inaccessible keychain). Durably suppress startup auto-login for
            // this profile instead of trapping the user in the session — an explicit
            // sign-out can then never be undone by a backend that becomes reachable
            // before the next launch; the next explicit login lifts the suppression and
            // reconciles the stored credential. The setter flushes to disk and reports
            // whether the marker verifiably persisted (mobile logout hard-exits right
            // after this handler): when NEITHER the deletion NOR the suppression can be
            // confirmed, keep the session so the user can retry.
            const suppressed = root.privacyStore.setAutoLoginSuppressed(root.keyUid, true)
            if (!suppressed) {
                Global.displayToastMessage(
                            qsTr("Failed to turn off automatic login — sign out aborted, please try again"),
                            "", "warning", false, Constants.ephemeralNotificationType.danger, "")
                root.close()
                return
            }
        }
        root.signOutRequested()
    }
}
