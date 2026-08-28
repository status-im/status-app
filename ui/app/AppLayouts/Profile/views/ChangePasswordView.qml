import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

import shared.panels
import shared.controls
import shared.popups
import shared.stores
import shared.views
import utils

import StatusQ
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components
import StatusQ.Popups
import StatusQ.Popups.Dialog

import AppLayouts.Profile.popups
import AppLayouts.Profile.stores

SettingsContentBase {
    id: root

    property PrivacyStore privacyStore
    required property Keychain keychain
    required property SecureStorage secureStorage

    QtObject {
        id: d

        readonly property int maxContentWidth: 507 // By design

        // Read-only flag that turns true when the footer row component enters a “compact” layout automatically on resize.
        readonly property bool compactFooterMode: flatButton.implicitWidth + confirmBtnFirstRowItem.implicitWidth + 2 * Theme.padding > root.width

        property int reevaluateTrigger
        function reevaluateHasCredential() {
            reevaluateTrigger++
        }

        property bool enablingBiometrics: false

        // "Stay logged in" state
        property bool enablingStayLoggedIn: false
        property bool migrationAuthPending: false
        property bool migratingProfile: false
        property string migrationPassword

        readonly property bool stayLoggedInEnabled: root.privacyStore.stayLoggedIn
        readonly property bool profileMigrated: {
            reevaluateTrigger // Reference for binding
            return root.privacyStore.isProfileMigratedToDEKEncryption()
        }

        function showStayLoggedInErrorToast() {
            Global.displayToastMessage(
                        qsTr("Failed to enable Stay logged in for this device"),
                        "", "warning", false, Constants.ephemeralNotificationType.danger, "")
        }

        function handleMigrationResult(success, errorMsg) {
            const password = d.migrationPassword
            d.migrationPassword = ""
            d.migratingProfile = false
            if (!success) {
                Global.displayToastMessage(
                            qsTr("Failed to migrate to the new encryption format: %1").arg(errorMsg),
                            "", "warning", false, Constants.ephemeralNotificationType.danger, "")
                return
            }
            // Refresh the biometric credential with the same password — this also
            // upgrades a legacy (raw password) item to the wrapped DEK now that the
            // profile is migrated.
            if (root.keychain.hasCredential(root.privacyStore.keyUid) === Keychain.StatusSuccess) {
                const cred = root.privacyStore.getBiometricCredentialForStorage(root.privacyStore.keyUid, password)
                if (cred === "" || root.keychain.updateCredential(root.privacyStore.keyUid, cred) !== Keychain.StatusSuccess) {
                    // Never leave a stale credential behind: disable biometrics
                    d.pendingFailureDelete = true
                    const deleteStatus = root.keychain.deleteCredential(root.privacyStore.keyUid)
                    if (deleteStatus !== Keychain.StatusSuccess) {
                        d.pendingFailureDelete = false
                        root.privacyStore.setBiometricPreferenceNotNow()
                    }
                    Global.displayToastMessage(
                                qsTr("Biometric login disabled — re-enable it in Settings"),
                                "", "warning", false, Constants.ephemeralNotificationType.danger, "")
                }
            }
            d.reevaluateHasCredential()
            // The migration re-encrypted the databases — like any deep password change,
            // the app must restart before it can continue.
            migrationRestartDialog.open()
        }

        // Set when a credential-update failure forces a deletion
        property bool pendingFailureDelete: false

        readonly property bool biometricsEnabled: {
            reevaluateTrigger // Reference for binding
            return keychain.hasCredential(privacyStore.keyUid) === Keychain.StatusSuccess
        }

        function showErrorToast() {
            Global.displayToastMessage(
                        qsTr("Failed to enable biometric login and transaction authentication for this device"),
                        "", "warning", false, Constants.ephemeralNotificationType.danger, "")
        }

        function showSuccessToast() {
            Global.displayToastMessage(
                        qsTr("Biometric login and transaction authentication enabled for this device"),
                        "", "checkmark-circle", false, Constants.ephemeralNotificationType.success, "")
        }

        function openConfirmChangePasswordPopup() {
            confirmPasswordChangePopup.fastPasswordChangePossible = root.privacyStore.isProfileMigratedToDEKEncryption()
            confirmPasswordChangePopup.open()
        }
    }

    readonly property Item biometricsPopup: titleRowComponentLoader.item
    readonly property Connections authenticationConnections: Connections {
        target: Global
        enabled: d.enablingBiometrics

        function onAuthenticationResult(reason, password, pin, keyUid) {
            if (reason !== Constants.authenticationReason.enableBiometrics)
                return
            d.enablingBiometrics = false

            const credential = pin !== "" ?
                                 pin
                               : root.privacyStore.getBiometricCredentialForStorage(keyUid, password)
            // If credential not retrieved (cancelled, failed, or could not be prepared)
            if (keyUid === "" || credential === "") {
                d.showErrorToast()
                return
            }

            const status = keychain.saveCredential(keyUid, credential)

            if (status !== Keychain.StatusSuccess) {
                d.showErrorToast()
                return
            }

            d.reevaluateHasCredential()
        }
    }
    readonly property Connections stayLoggedInAuthConnections: Connections {
        target: Global
        enabled: d.enablingStayLoggedIn || d.migrationAuthPending

        function onAuthenticationResult(reason, password, pin, keyUid) {
            if (reason === Constants.authenticationReason.enableStayLoggedIn) {
                if (!d.enablingStayLoggedIn)
                    return
                d.enablingStayLoggedIn = false
                if (keyUid === "")
                    return // cancelled
                if (pin !== "") {
                    d.showStayLoggedInErrorToast() // keycard profiles are out of scope
                    return
                }
                const credential = root.privacyStore.getStayLoggedInCredentialForStorage(keyUid, password)
                if (credential === ""
                        || root.secureStorage.setCredential(keyUid, credential) !== SecureStorage.StatusSuccess) {
                    d.showStayLoggedInErrorToast()
                    return
                }
                root.privacyStore.setStayLoggedIn(true)
                Global.displayToastMessage(
                            qsTr("Stay logged in enabled for this device"),
                            "", "checkmark-circle", false, Constants.ephemeralNotificationType.success, "")
            } else if (reason === Constants.authenticationReason.migrateProfileEncryption) {
                if (!d.migrationAuthPending)
                    return
                d.migrationAuthPending = false
                if (keyUid === "" || pin !== "")
                    return // cancelled, or unsupported keycard auth
                d.migrationPassword = password
                d.migratingProfile = true
                // In-place migration: same password, no rekey — status-go performs the
                // one-time legacy -> DEK re-encryption on the deep-change machinery.
                root.privacyStore.changePassword(password, password, false)
            }
        }
    }
    readonly property Connections keychainConnections: Connections {
        target: root.keychain

        function onCredentialSaved(account: string) {
            d.showSuccessToast()
            d.reevaluateHasCredential()
        }

        function onCredentialDeleted(account: string) {
            if (!d.pendingFailureDelete || account !== root.privacyStore.keyUid)
                return
            d.pendingFailureDelete = false
            // The global deletion handler records a permanent "never" opt-out
            Qt.callLater(() => root.privacyStore.setBiometricPreferenceNotNow())
            d.reevaluateHasCredential()
        }

        function onGetCredentialRequestCompleted(status, secret) {
            if (status !== Keychain.StatusSuccess) {
                d.showErrorToast()
            }
            d.reevaluateHasCredential()
        }
    }

    property var passwordStrengthScoreFunction: function () {}

    ColumnLayout {
        spacing: 12
        width: Math.min(d.maxContentWidth, root.contentWidth)

        BiometricsSectionView {
            Layout.fillWidth: true

            enabled: root.keychain.available
            biometricsAvailable: root.keychain.available
            biometricsEnabled: d.biometricsEnabled
            onToggleBiometrics: function(checked) {
                // Enable Biometrics flow
                if (!checked) {
                    d.enablingBiometrics = true
                    Global.openAuthenticationPopup(Constants.authenticationReason.enableBiometrics, root.privacyStore.keyUid, false)
                    return
                }

                // Disable biometrics flow
                const status = root.keychain.deleteCredential(root.privacyStore.keyUid)

                switch (status) {
                case Keychain.StatusSuccess:
                    Global.displayToastMessage(
                                qsTr("Biometric login and transaction authentication disabled for this device"),
                                "", "checkmark-circle", false, Constants.ephemeralNotificationType.success, "")
                    break
                default:
                    Global.displayToastMessage(
                                qsTr("Failed to disable biometric login and transaction authentication for this device"),
                                "", "warning", false, Constants.ephemeralNotificationType.danger, "")
                }
                d.reevaluateHasCredential()
            }
        }

        StatusModalDivider {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
        }

        StayLoggedInSectionView {
            objectName: "stayLoggedInSection"
            Layout.fillWidth: true

            storageAvailable: root.secureStorage.available
            stayLoggedInEnabled: d.stayLoggedInEnabled
            profileMigrated: d.profileMigrated
            busy: d.migratingProfile

            onToggleStayLoggedIn: function(checked) {
                // Enable flow: the password is needed to export the DEK
                if (!checked) {
                    d.enablingStayLoggedIn = true
                    Global.openAuthenticationPopup(Constants.authenticationReason.enableStayLoggedIn, root.privacyStore.keyUid, false)
                    return
                }

                // Disable flow: delete the credential FIRST (startup trusts credential
                // presence), then flip the preference
                const status = root.secureStorage.deleteCredential(root.privacyStore.keyUid)
                if (status !== SecureStorage.StatusSuccess && status !== SecureStorage.StatusNotFound) {
                    Global.displayToastMessage(
                                qsTr("Failed to disable Stay logged in for this device"),
                                "", "warning", false, Constants.ephemeralNotificationType.danger, "")
                    return
                }
                root.privacyStore.setStayLoggedIn(false)
                Global.displayToastMessage(
                            qsTr("Stay logged in disabled for this device"),
                            "", "checkmark-circle", false, Constants.ephemeralNotificationType.success, "")
            }
            onMigrateRequested: {
                d.migrationAuthPending = true
                Global.openAuthenticationPopup(Constants.authenticationReason.migrateProfileEncryption, root.privacyStore.keyUid, false)
            }
        }

        StatusModalDivider {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
        }

        PasswordView {
            id: choosePasswordForm

            Layout.fillWidth: true

            createNewPsw: false
            title: qsTr("Change your password")
            titleSize: 17
            contentAlignment: Qt.AlignLeft
            highSizeIntro: true
            passwordStrengthScoreFunction: root.passwordStrengthScoreFunction

            onReturnPressed: {
                if (ready) {
                    d.openConfirmChangePasswordPopup();
                }
            }
        }

        StatusModalDivider {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.fillWidth: true

            StatusFlatButton {
                id: flatButton
                text: qsTr("Cancel")
                onClicked: choosePasswordForm.reset()
            }

            Item { Layout.fillWidth: true }

            LayoutItemProxy {
                id: confirmBtnFirstRowItem
                visible: !d.compactFooterMode
                Layout.alignment: Qt.AlignRight

                target: confirmButton
            }
        }

        LayoutItemProxy {
            visible: d.compactFooterMode
            Layout.alignment: Qt.AlignLeft

            target: confirmButton
        }

        ConfirmChangePasswordModal {
            id: confirmPasswordChangePopup
            onChangePasswordRequested: function(rekey) {
                root.privacyStore.changePassword(choosePasswordForm.currentPswText, choosePasswordForm.newPswText, rekey);
            }

            Connections {
                target: root.privacyStore.privacyModule
                function onPasswordChanged(success: bool, errorMsg: string) {
                    if (d.migratingProfile) {
                        d.handleMigrationResult(success, errorMsg)
                        return
                    }
                    if (success) {
                        confirmPasswordChangePopup.passwordSuccessfulyChanged()
                        if (root.keychain.hasCredential(root.privacyStore.keyUid) === Keychain.StatusSuccess) {
                            const cred = root.privacyStore.getBiometricCredentialForStorage(root.privacyStore.keyUid, choosePasswordForm.newPswText)
                            const ok = cred !== ""
                                     && root.keychain.updateCredential(root.privacyStore.keyUid, cred) === Keychain.StatusSuccess
                            if (!ok) {
                                // Never leave a stale credential behind: disable biometrics
                                d.pendingFailureDelete = true
                                const deleteStatus = root.keychain.deleteCredential(root.privacyStore.keyUid)
                                if (deleteStatus !== Keychain.StatusSuccess) {
                                    // No credentialDeleted signal will arrive - clear the pending flag
                                    d.pendingFailureDelete = false
                                    root.privacyStore.setBiometricPreferenceNotNow()
                                }
                                Global.displayToastMessage(
                                            qsTr("Biometric login disabled — re-enable it in Settings"),
                                            "",
                                            "warning",
                                            false,
                                            Constants.ephemeralNotificationType.danger,
                                            "")
                                d.reevaluateHasCredential()
                            }
                        }
                        // Keep the "Stay logged in" credential in sync: a deep rekey
                        // mints a new DEK, so the stored credential must be refreshed
                        // from the new password.
                        if (root.secureStorage.hasCredential(root.privacyStore.keyUid) === SecureStorage.StatusSuccess) {
                            const silentCred = root.privacyStore.getStayLoggedInCredentialForStorage(root.privacyStore.keyUid, choosePasswordForm.newPswText)
                            const silentOk = silentCred !== ""
                                     && root.secureStorage.setCredential(root.privacyStore.keyUid, silentCred) === SecureStorage.StatusSuccess
                            if (!silentOk) {
                                // Never leave a stale credential behind: disable the
                                // feature — but flip the preference ONLY when the
                                // deletion verifiably succeeded. Startup trusts
                                // credential presence, so "preference off + credential
                                // possibly present" must never be produced here.
                                const silentDeleteStatus = root.secureStorage.deleteCredential(root.privacyStore.keyUid)
                                if (silentDeleteStatus === SecureStorage.StatusSuccess
                                        || silentDeleteStatus === SecureStorage.StatusNotFound) {
                                    root.privacyStore.setStayLoggedIn(false)
                                    Global.displayToastMessage(
                                                qsTr("Stay logged in disabled — re-enable it in Settings"),
                                                "", "warning", false, Constants.ephemeralNotificationType.danger, "")
                                } else {
                                    // Preference stays ON: the stored (possibly stale)
                                    // credential is reconciled by the post-login task /
                                    // auto-login failure fallback.
                                    Global.displayToastMessage(
                                                qsTr("Failed to update the Stay logged in credential"),
                                                "", "warning", false, Constants.ephemeralNotificationType.danger, "")
                                }
                            }
                        }
                        // Reset, cause no restart in this case.
                        choosePasswordForm.reset()
                        return
                    }

                    choosePasswordForm.reset()
                    choosePasswordForm.errorMsgText = errorMsg
                    confirmPasswordChangePopup.close()
                }
            }
        }
    }

    ConfirmationDialog {
        id: migrationRestartDialog

        objectName: "migrationRestartDialog"

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
                Qt.callLater(() => migrationRestartDialog.open())
        }
    }

    // Here there are defined the components used inside layout item proxy components:
    StatusButton {
        id: confirmButton
        objectName: "changePasswordModalSubmitButton"
        text: qsTr("Change")
        enabled: choosePasswordForm.ready
        onClicked: { d.openConfirmChangePasswordPopup(); }
    }
}
