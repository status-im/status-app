import QtQuick
import QtQuick.Controls

import shared.popups
import utils

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

// Owns the "migrate to the new encryption format" flow end to end: authentication
// result -> in-place password change -> biometric-credential refresh -> mandatory
// restart. It deliberately lives at the application level (instantiated by Popups),
// NOT in the settings view that starts it: the migration is asynchronous, and leaving
// the Profile section unloads that whole view. A non-dismissible modal covers the
// entire migration so nothing can be interacted with while the databases re-encrypt.
QtObject {
    id: root

    required property var privacyStore
    required property Keychain keychain
    required property var popupParent

    readonly property QtObject d: QtObject {
        id: d

        property bool migratingProfile: false
        property string migrationPassword

        // Set when a failed biometric-credential refresh forces a deletion
        property bool pendingFailureDelete: false

        function handleMigrationResult(success, errorMsg) {
            const password = d.migrationPassword
            d.migrationPassword = ""
            d.migratingProfile = false
            progressDialog.close()
            if (!success) {
                Global.displayToastMessage(
                            qsTr("Failed to migrate to the new encryption format: %1").arg(errorMsg),
                            "", "warning", false, Constants.ephemeralNotificationType.danger, "")
                return
            }
            // Refresh the biometric credential with the same password — this also
            // upgrades a legacy (raw password) item to the wrapped DEK now that the
            // profile is migrated.
            const keyUid = root.privacyStore.keyUid
            if (root.keychain.hasCredential(keyUid) === Keychain.StatusSuccess) {
                const cred = root.privacyStore.getBiometricCredentialForStorage(keyUid, password)
                if (cred === "" || root.keychain.updateCredential(keyUid, cred) !== Keychain.StatusSuccess) {
                    // Never leave a stale credential behind: disable biometrics
                    d.pendingFailureDelete = true
                    const deleteStatus = root.keychain.deleteCredential(keyUid)
                    if (deleteStatus !== Keychain.StatusSuccess) {
                        d.pendingFailureDelete = false
                        root.privacyStore.setBiometricPreferenceNotNow()
                    }
                    Global.displayToastMessage(
                                qsTr("Biometric login disabled — re-enable it in Settings"),
                                "", "warning", false, Constants.ephemeralNotificationType.danger, "")
                }
            }
            // The migration re-encrypted the databases — like any deep password change,
            // the app must restart before it can continue.
            restartDialog.open()
        }
    }

    readonly property Connections authConnections: Connections {
        target: Global

        function onAuthenticationResult(reason, password, pin, keyUid) {
            if (reason !== Constants.authenticationReason.migrateProfileEncryption)
                return
            if (keyUid === "" || pin !== "")
                return // cancelled, or unsupported keycard auth
            d.migrationPassword = password
            d.migratingProfile = true
            progressDialog.open()
            // In-place migration: same password, no rekey — status-go performs the
            // one-time legacy -> DEK re-encryption on the deep-change machinery.
            root.privacyStore.changePassword(password, password, false)
        }
    }

    readonly property Connections passwordChangedConnections: Connections {
        target: root.privacyStore ? root.privacyStore.privacyModule : null
        // Only reacts to the change THIS flow requested; ordinary password changes are
        // handled by the settings view that initiated them.
        enabled: d.migratingProfile

        function onPasswordChanged(success, errorMsg) {
            d.handleMigrationResult(success, errorMsg)
        }
    }

    readonly property Connections keychainConnections: Connections {
        target: root.keychain
        enabled: d.pendingFailureDelete

        function onCredentialDeleted(account) {
            if (account !== root.privacyStore.keyUid)
                return
            d.pendingFailureDelete = false
            // The app-level deletion handler records a permanent "never" opt-out
            Qt.callLater(() => root.privacyStore.setBiometricPreferenceNotNow())
        }
    }

    // Non-dismissible modal covering the whole asynchronous migration.
    readonly property StatusDialog progressDialog: StatusDialog {
        id: progressDialog

        objectName: "migrationProgressDialog"
        parent: root.popupParent
        width: 480
        title: qsTr("Updating encryption")
        standardButtons: Dialog.NoButton
        closePolicy: Popup.NoAutoClose

        StatusBaseText {
            anchors.fill: parent
            text: qsTr("Re-encrypting your data with the new encryption format. This may take some time — do not quit the app or turn off your device.")
            font.pixelSize: Theme.primaryTextFontSize
            color: Theme.palette.directColor1
            wrapMode: Text.WordWrap
        }

        onClosed: {
            // A close arriving through any unexpected path while the migration still
            // runs immediately reopens the dialog.
            if (d.migratingProfile)
                Qt.callLater(() => progressDialog.open())
        }
    }

    readonly property ConfirmationDialog restartDialog: ConfirmationDialog {
        id: restartDialog

        objectName: "migrationRestartDialog"
        parent: root.popupParent

        property bool restartTriggered: false

        headerSettings.title: qsTr("Encryption updated")
        confirmationText: qsTr("Your profile was migrated to the new encryption format. Status must restart to complete the process.")
        confirmButtonLabel: qsTr("Restart Status")
        // The migration deep-re-encrypted the databases — restarting is the only way
        // out. Esc/overlay dismissal is disabled, and a close arriving through any
        // other path (e.g. the header close button) immediately reopens the dialog.
        escapeKeyCloses: false
        closeOnOverlayClick: false
        onConfirmButtonClicked: {
            restartTriggered = true
            SystemUtils.restartApplication(true)
        }
        onClosed: {
            if (!restartTriggered)
                Qt.callLater(() => restartDialog.open())
        }
    }
}
