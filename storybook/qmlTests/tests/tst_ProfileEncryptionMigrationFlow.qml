import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ

import mainui
import utils

Item {
    id: root

    width: 600
    height: 500

    readonly property string testKeyUid: "key-uid-1"

    // Simulates the app-level biometric preference ("store"/"notNow"/"never").
    property string preference: "store"

    // What the biometric credential transform returns; "" simulates a helper failure.
    property string transformResult: "dek:fresh-dek-hex"

    property var changePasswordCalls: []

    property var keychainMock: null
    property var migrationFlow: null

    Component {
        id: mockedKeychainComponent

        // Shadows the C++ members so no real OS keychain/biometrics is touched
        Keychain {
            property var creds: ({})
            property var updateCalls: []
            property int updateStatus: Keychain.StatusSuccess
            property int deleteStatus: Keychain.StatusSuccess

            function hasCredential(account) {
                return creds[account] !== undefined ? Keychain.StatusSuccess
                                                    : Keychain.StatusNotFound
            }
            function updateCredential(account, credential) {
                updateCalls.push({ account, credential })
                if (updateStatus === Keychain.StatusSuccess && creds[account] !== undefined)
                    creds[account] = credential
                return updateStatus
            }
            function deleteCredential(account) {
                if (deleteStatus !== Keychain.StatusSuccess)
                    return deleteStatus // failure: item untouched, no signal emitted
                delete creds[account]
                credentialDeleted(account)
                return Keychain.StatusSuccess
            }
            function requestGetCredential(reason, account) {}
        }
    }

    Component {
        id: flowComponent

        ProfileEncryptionMigrationFlow {
            popupParent: root
            keychain: root.keychainMock

            privacyStore: QtObject {
                readonly property string keyUid: root.testKeyUid

                property QtObject privacyModule: QtObject {
                    signal passwordChanged(success: bool, errorMsg: string)
                }

                function changePassword(password, newPassword, rekey = false) {
                    root.changePasswordCalls.push({ password, newPassword, rekey })
                }
                function getBiometricCredentialForStorage(keyUid, password) {
                    return root.transformResult
                }
                function setBiometricPreferenceNotNow() {
                    root.preference = "notNow"
                }
            }
        }
    }

    TestCase {
        name: "ProfileEncryptionMigrationFlow"
        when: windowShown

        function init() {
            root.preference = "store"
            root.transformResult = "dek:fresh-dek-hex"
            root.changePasswordCalls = []
            root.keychainMock = createTemporaryObject(mockedKeychainComponent, root)
            verify(!!root.keychainMock)
            root.migrationFlow = createTemporaryObject(flowComponent, root)
            verify(!!root.migrationFlow)
        }

        function cleanup() {
            // Leave no (self-reopening) modal behind for the next test
            if (root.migrationFlow) {
                root.migrationFlow.d.migratingProfile = false
                root.migrationFlow.progressDialog.close()
                root.migrationFlow.restartDialog.restartTriggered = true
                root.migrationFlow.restartDialog.close()
                tryVerify(() => !root.migrationFlow.progressDialog.opened
                                && !root.migrationFlow.restartDialog.opened)
                root.migrationFlow = null
            }
        }

        function startMigration() {
            Global.authenticationResult(Constants.authenticationReason.migrateProfileEncryption,
                                        "password-1", "", root.testKeyUid, "")
        }

        // Authentication result -> same-password non-rekey change, covered by a
        // non-dismissible modal for the whole asynchronous migration.
        function test_authStartsMigrationUnderBlockingModal() {
            startMigration()

            compare(root.changePasswordCalls.length, 1)
            compare(root.changePasswordCalls[0].password, "password-1")
            compare(root.changePasswordCalls[0].newPassword, "password-1")
            compare(root.changePasswordCalls[0].rekey, false)

            const progress = root.migrationFlow.progressDialog
            tryVerify(() => progress.opened)
            compare(progress.closePolicy, Popup.NoAutoClose)

            // A close arriving while the migration still runs immediately reopens
            progress.close()
            tryVerify(() => progress.opened)
        }

        function test_ignoresUnrelatedOrCancelledAuth_data() {
            return [
                { tag: "other reason", reason: Constants.authenticationReason.enableStayLoggedIn,
                  password: "password-1", pin: "", keyUid: root.testKeyUid },
                { tag: "cancelled", reason: Constants.authenticationReason.migrateProfileEncryption,
                  password: "", pin: "", keyUid: "" },
                { tag: "keycard auth unsupported", reason: Constants.authenticationReason.migrateProfileEncryption,
                  password: "", pin: "123456", keyUid: root.testKeyUid },
            ]
        }

        function test_ignoresUnrelatedOrCancelledAuth(data) {
            Global.authenticationResult(data.reason, data.password, data.pin, data.keyUid, "")

            compare(root.changePasswordCalls.length, 0)
            verify(!root.migrationFlow.progressDialog.opened)
        }

        // Success: biometric item refreshed with the wrapped DEK (same password), the
        // progress modal is replaced by the non-dismissible restart dialog — restart is
        // the only way out of a deep re-encryption.
        function test_successRefreshesBiometricsAndForcesRestart() {
            root.keychainMock.creds[root.testKeyUid] = "legacy-password"

            startMigration()
            root.migrationFlow.privacyStore.privacyModule.passwordChanged(true, "")

            compare(root.keychainMock.updateCalls.length, 1)
            compare(root.keychainMock.updateCalls[0].account, root.testKeyUid)
            compare(root.keychainMock.updateCalls[0].credential, "dek:fresh-dek-hex")
            compare(root.preference, "store")

            tryVerify(() => !root.migrationFlow.progressDialog.opened)

            const dialog = root.migrationFlow.restartDialog
            tryVerify(() => dialog.opened)
            compare(dialog.escapeKeyCloses, false)
            compare(dialog.closeOnOverlayClick, false)

            // Any close that is not the restart action immediately reopens the dialog
            dialog.close()
            tryVerify(() => dialog.opened)
        }

        // Success without a stored biometric item: the keychain is never touched.
        function test_successWithoutBiometricItemLeavesKeychainAlone() {
            startMigration()
            root.migrationFlow.privacyStore.privacyModule.passwordChanged(true, "")

            compare(root.keychainMock.updateCalls.length, 0)
            tryVerify(() => root.migrationFlow.restartDialog.opened)
        }

        // Failure: the modal is dismissed, no restart is forced, nothing is touched.
        function test_failureClosesModalWithoutRestart() {
            root.keychainMock.creds[root.testKeyUid] = "legacy-password"

            startMigration()
            root.migrationFlow.privacyStore.privacyModule.passwordChanged(false, "some error")

            tryVerify(() => !root.migrationFlow.progressDialog.opened)
            verify(!root.migrationFlow.restartDialog.opened)
            compare(root.keychainMock.updateCalls.length, 0)
            compare(root.keychainMock.creds[root.testKeyUid], "legacy-password")
        }

        // Failed biometric refresh after a successful migration: never leave a stale
        // credential behind — the item is deleted and the preference corrected to
        // "notNow" (the app-level deletion handler records "never" first); the restart
        // is still forced.
        function test_biometricRefreshFailureDisablesBiometrics() {
            root.keychainMock.creds[root.testKeyUid] = "legacy-password"
            root.transformResult = "" // conversion failure

            startMigration()
            root.migrationFlow.privacyStore.privacyModule.passwordChanged(true, "")

            compare(root.keychainMock.creds[root.testKeyUid], undefined)

            // drain the Qt.callLater queue deterministically
            let drained = false
            Qt.callLater(() => drained = true)
            tryVerify(() => drained)
            compare(root.preference, "notNow")

            tryVerify(() => root.migrationFlow.restartDialog.opened)
        }
    }
}
