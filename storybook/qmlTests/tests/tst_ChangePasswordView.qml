import QtQuick
import QtQuick.Controls

import QtTest

import StatusQ

import AppLayouts.Profile.views
import AppLayouts.Profile.stores

import utils

Item {
    id: root

    width: 600
    height: 700

    readonly property string testKeyUid: "key-uid-1"

    // Simulates the app-level biometric preference ("store"/"notNow"/"never").
    property string preference: "store"

    // What the credential transform returns; "" simulates a helper failure.
    property string transformResult: "dek:fresh-dek-hex"

    // What the DEK-only "Stay logged in" transform returns; "" simulates a legacy
    // profile or a helper failure (that converter never returns a raw password).
    property string silentTransformResult: "dek:silent-dek-hex"

    property bool profileMigratedMock: true
    property var changePasswordCalls: []

    property var keychainMock: null
    property var secureStorageMock: null
    property var view: null

    Component {
        id: mockedKeychainComponent

        // Shadows the C++ members so no real OS keychain/biometrics is touched
        Keychain {
            property var creds: ({})
            property bool asyncDelete: false // Android-style delivery of credentialDeleted
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
                if (asyncDelete)
                    Qt.callLater(() => credentialDeleted(account))
                else
                    credentialDeleted(account)
                return Keychain.StatusSuccess
            }
            function requestGetCredential(reason, account) {}
        }
    }

    Component {
        id: mockedSecureStorageComponent

        // Shadows the C++ members so no real OS secure storage is touched
        SecureStorage {
            property bool available: true
            property var creds: ({})
            property var setCalls: []
            property var deleteCalls: []
            property int setStatus: SecureStorage.StatusSuccess
            property int deleteStatus: SecureStorage.StatusSuccess
            // Models the Linux timeout case: StatusIndeterminate returned to the caller
            // while the write actually committed in the background.
            property bool commitOnIndeterminate: false

            function hasCredential(account) {
                return creds[account] !== undefined ? SecureStorage.StatusSuccess
                                                    : SecureStorage.StatusNotFound
            }
            function setCredential(account, credential) {
                setCalls.push({ account, credential })
                if (setStatus === SecureStorage.StatusSuccess
                        || (setStatus === SecureStorage.StatusIndeterminate && commitOnIndeterminate))
                    creds[account] = credential
                return setStatus
            }
            function deleteCredential(account) {
                deleteCalls.push({ account })
                if (deleteStatus !== SecureStorage.StatusSuccess)
                    return deleteStatus // failure/indeterminate: item untouched
                if (creds[account] === undefined)
                    return SecureStorage.StatusNotFound
                delete creds[account]
                return SecureStorage.StatusSuccess
            }
            function getCredential(account) {
                const value = creds[account]
                return { status: value === undefined ? SecureStorage.StatusNotFound
                                                     : SecureStorage.StatusSuccess,
                         credential: value === undefined ? "" : value }
            }
        }
    }

    // Mimics ui/main.qml's app-level handler: ANY deletion records a permanent opt-out.
    // Declared before the view is created, matching the app's connection order.
    Connections {
        target: root.keychainMock

        function onCredentialDeleted(account) {
            root.preference = "never"
        }
    }

    Component {
        id: viewComponent

        ChangePasswordView {
            sectionTitle: "Password"
            contentWidth: 500
            passwordStrengthScoreFunction: (newPass) => Math.min(newPass.length - 1, 4)

            privacyStore: PrivacyStore {
                // The storybook PrivacyStore stub is empty; the API used by the view is
                // declared here, following the established qmlTests store-mock pattern.
                readonly property string keyUid: root.testKeyUid

                property QtObject privacyModule: QtObject {
                    signal passwordChanged(success: bool, errorMsg: string)
                }

                function changePassword(password, newPassword, rekey = false) {
                    root.changePasswordCalls.push({ password, newPassword, rekey })
                }

                function isProfileMigratedToDEKEncryption() {
                    return root.profileMigratedMock
                }

                function getBiometricCredentialForStorage(keyUid, password) {
                    return root.transformResult
                }

                function setBiometricPreferenceNotNow() {
                    root.preference = "notNow"
                }

                property bool stayLoggedIn: false
                function setStayLoggedIn(value) {
                    stayLoggedIn = value
                }
                function getStayLoggedInCredentialForStorage(keyUid, password) {
                    // DEK-only conversion: tagged DEK or "" (never a raw password)
                    return root.silentTransformResult
                }
            }

            keychain: root.keychainMock
            secureStorage: root.secureStorageMock
        }
    }

    TestCase {
        name: "ChangePasswordView_keychainFlow"
        when: windowShown

        function init() {
            root.preference = "store"
            root.transformResult = "dek:fresh-dek-hex"
            root.silentTransformResult = "dek:silent-dek-hex"
            root.profileMigratedMock = true
            root.changePasswordCalls = []
            root.keychainMock = createTemporaryObject(mockedKeychainComponent, root)
            verify(!!root.keychainMock)
            root.keychainMock.deleteStatus = Keychain.StatusSuccess
            root.secureStorageMock = createTemporaryObject(mockedSecureStorageComponent, root)
            verify(!!root.secureStorageMock)
            root.view = createTemporaryObject(viewComponent, root)
            verify(!!root.view)
        }

        function cleanup() {
            if (root.view) {
                root.view.destroy()
                root.view = null
            }
            // keychainMock is left in place until init() replaces it: the view's destroy is
            // deferred and its bindings would re-evaluate against a null keychain.
        }

        function emitPasswordChanged(success) {
            const newPswInput = findChild(root.view, "passwordViewNewPassword")
            verify(!!newPswInput)
            newPswInput.text = "new-password-1"
            // Request the change through the view's own modal first: the view only
            // handles passwordChanged signals for changes it requested itself.
            const modal = findChild(root.view, "confirmChangePasswordModal")
            verify(!!modal)
            modal.changePasswordRequested(false)
            root.view.privacyStore.privacyModule.passwordChanged(success, success ? "" : "some error")
        }

        // Successful change with a stored item: the item is refreshed with the transformed
        // credential (wrapped DEK); the preference is untouched.
        function test_successRefreshesStoredCredential() {
            root.keychainMock.creds[root.testKeyUid] = "old-password"

            emitPasswordChanged(true)

            compare(root.keychainMock.updateCalls.length, 1)
            compare(root.keychainMock.updateCalls[0].account, root.testKeyUid)
            compare(root.keychainMock.updateCalls[0].credential, "dek:fresh-dek-hex")
            compare(root.keychainMock.creds[root.testKeyUid], "dek:fresh-dek-hex")
            compare(root.preference, "store")
        }

        // No stored item: the keychain is never touched.
        function test_successWithoutItemLeavesKeychainAlone() {
            emitPasswordChanged(true)

            compare(root.keychainMock.updateCalls.length, 0)
            compare(root.preference, "store")
        }

        // Failed password change: the keychain is never touched.
        function test_failureLeavesKeychainAlone() {
            root.keychainMock.creds[root.testKeyUid] = "old-password"

            emitPasswordChanged(false)

            compare(root.keychainMock.updateCalls.length, 0)
            compare(root.keychainMock.creds[root.testKeyUid], "old-password")
            compare(root.preference, "store")
        }

        function test_storageFailureDisablesBiometrics_data() {
            return [
                { tag: "helper failure, sync delete", transform: "", updateStatus: Keychain.StatusSuccess, asyncDelete: false },
                { tag: "helper failure, async delete (Android)", transform: "", updateStatus: Keychain.StatusSuccess, asyncDelete: true },
                { tag: "update failure, sync delete", transform: "dek:fresh-dek-hex", updateStatus: Keychain.StatusGenericError, asyncDelete: false },
                { tag: "update failure, async delete (Android)", transform: "dek:fresh-dek-hex", updateStatus: Keychain.StatusGenericError, asyncDelete: true },
            ]
        }

        // A storage failure deletes the stale item and must end with the preference on
        // "notNow" — even though the deletion handler records "never", and even when
        // credentialDeleted arrives asynchronously (Android).
        function test_storageFailureDisablesBiometrics(data) {
            root.transformResult = data.transform
            root.keychainMock.updateStatus = data.updateStatus
            root.keychainMock.asyncDelete = data.asyncDelete
            root.keychainMock.creds[root.testKeyUid] = "old-password"

            emitPasswordChanged(true)

            tryVerify(() => root.keychainMock.creds[root.testKeyUid] === undefined)
            tryCompare(root, "preference", "notNow")
        }

        // A FAILED deletion emits no credentialDeleted: the failure preference must still be
        // applied directly, and the pending flag must not leak onto a later explicit deletion
        // (which records a permanent "never" opt-out and must stay that way).
        function test_deletionFailureAppliesPreferenceAndDoesNotPoisonLaterDeletes() {
            root.transformResult = "" // helper failure triggers the deletion path
            root.keychainMock.deleteStatus = Keychain.StatusGenericError
            root.keychainMock.creds[root.testKeyUid] = "old-password"

            emitPasswordChanged(true)

            compare(root.keychainMock.creds[root.testKeyUid], "old-password") // deletion failed
            tryCompare(root, "preference", "notNow")

            // later, the user explicitly disables biometrics
            root.preference = "store"
            root.keychainMock.deleteStatus = Keychain.StatusSuccess
            root.keychainMock.deleteCredential(root.testKeyUid)

            // drain the Qt.callLater queue deterministically: any (wrongly) deferred
            // correction was queued before this sentinel, so it has run once we see it
            let drained = false
            Qt.callLater(() => drained = true)
            tryVerify(() => drained)
            compare(root.preference, "never")
        }

        //////////////////////////////////////////////////////////////////////////
        // Biometrics toggle flows
        //////////////////////////////////////////////////////////////////////////

        function biometricsSection() {
            const section = findChild(root.view, "biometricsSection")
            verify(!!section)
            return section
        }

        // Disabling biometrics requires authentication (deliberate, although deleting
        // the item needs no password technically): the user must prove they still know
        // the credential they will be left with. The item is only deleted after a
        // successful authentication result.
        function test_biometricsDisableRequiresAuth() {
            root.keychainMock.creds[root.testKeyUid] = "dek:stored-dek-hex"

            biometricsSection().toggleBiometrics(true) // switch was checked -> disable
            compare(root.keychainMock.creds[root.testKeyUid], "dek:stored-dek-hex") // nothing deleted yet

            Global.authenticationResult(Constants.authenticationReason.disableBiometrics,
                                        "password-1", "", root.testKeyUid, "")

            compare(root.keychainMock.creds[root.testKeyUid], undefined)
        }

        // A cancelled authentication leaves biometrics enabled and the item untouched.
        function test_biometricsDisableCancelledAuthKeepsItem() {
            root.keychainMock.creds[root.testKeyUid] = "dek:stored-dek-hex"

            biometricsSection().toggleBiometrics(true)
            Global.authenticationResult(Constants.authenticationReason.disableBiometrics,
                                        "", "", "", "") // cancelled

            compare(root.keychainMock.creds[root.testKeyUid], "dek:stored-dek-hex")
            compare(root.preference, "store")
        }

        //////////////////////////////////////////////////////////////////////////
        // "Stay logged in" flows
        //////////////////////////////////////////////////////////////////////////

        function stayLoggedInSection() {
            const section = findChild(root.view, "stayLoggedInSection")
            verify(!!section)
            return section
        }

        // Enabling: auth result -> DEK-only conversion -> stored -> preference ON.
        function test_stayLoggedInEnableSuccess() {
            stayLoggedInSection().toggleStayLoggedIn(false) // switch was unchecked

            Global.authenticationResult(Constants.authenticationReason.enableStayLoggedIn,
                                        "password-1", "", root.testKeyUid, "")

            compare(root.secureStorageMock.setCalls.length, 1)
            compare(root.secureStorageMock.setCalls[0].account, root.testKeyUid)
            compare(root.secureStorageMock.setCalls[0].credential, "dek:silent-dek-hex")
            compare(root.view.privacyStore.stayLoggedIn, true)
        }

        // DEK-only conversion failure (legacy profile / helper error): nothing is
        // stored and the preference stays OFF.
        function test_stayLoggedInEnableConversionFailure() {
            root.silentTransformResult = ""

            stayLoggedInSection().toggleStayLoggedIn(false)
            Global.authenticationResult(Constants.authenticationReason.enableStayLoggedIn,
                                        "password-1", "", root.testKeyUid, "")

            compare(root.secureStorageMock.setCalls.length, 0)
            compare(root.view.privacyStore.stayLoggedIn, false)
        }

        // Storage failure while enabling: the preference stays OFF.
        function test_stayLoggedInEnableStoreFailure() {
            root.secureStorageMock.setStatus = SecureStorage.StatusGenericError

            stayLoggedInSection().toggleStayLoggedIn(false)
            Global.authenticationResult(Constants.authenticationReason.enableStayLoggedIn,
                                        "password-1", "", root.testKeyUid, "")

            compare(root.secureStorageMock.setCalls.length, 1)
            compare(root.view.privacyStore.stayLoggedIn, false)
        }

        function test_stayLoggedInEnableIndeterminate_data() {
            return [
                { tag: "cleanup verified -> disabled", committed: true, deleteStatus: SecureStorage.StatusSuccess, expectedPref: false, expectCredential: false },
                { tag: "nothing committed -> disabled", committed: false, deleteStatus: SecureStorage.StatusSuccess, expectedPref: false, expectCredential: false },
                { tag: "cleanup failed -> worst case enabled", committed: true, deleteStatus: SecureStorage.StatusGenericError, expectedPref: true, expectCredential: true },
                { tag: "cleanup indeterminate -> worst case enabled", committed: false, deleteStatus: SecureStorage.StatusIndeterminate, expectedPref: true },
            ]
        }

        // An indeterminate store (e.g. a Secret Service timeout — the write MAY have
        // committed) first attempts a converging deletion. Verified deletion -> the
        // feature stays OFF; an unverifiable cleanup leaves the preference ON
        // (worst-case alignment: never contradict a possibly stored credential — the
        // post-login task reconciles on the next login either way).
        function test_stayLoggedInEnableIndeterminate(data) {
            root.secureStorageMock.setStatus = SecureStorage.StatusIndeterminate
            root.secureStorageMock.commitOnIndeterminate = data.committed
            root.secureStorageMock.deleteStatus = data.deleteStatus

            stayLoggedInSection().toggleStayLoggedIn(false)
            Global.authenticationResult(Constants.authenticationReason.enableStayLoggedIn,
                                        "password-1", "", root.testKeyUid, "")

            compare(root.secureStorageMock.setCalls.length, 1)
            compare(root.secureStorageMock.deleteCalls.length, 1) // convergence attempt
            compare(root.view.privacyStore.stayLoggedIn, data.expectedPref)
            if (data.expectCredential !== undefined)
                compare(root.secureStorageMock.creds[root.testKeyUid] !== undefined, data.expectCredential)
        }

        function test_stayLoggedInDisable_data() {
            return [
                { tag: "verified deletion", deleteStatus: SecureStorage.StatusSuccess, expectedPref: false },
                { tag: "nothing stored", deleteStatus: SecureStorage.StatusSuccess, noItem: true, expectedPref: false },
                { tag: "deletion error", deleteStatus: SecureStorage.StatusGenericError, expectedPref: true },
                { tag: "deletion indeterminate", deleteStatus: SecureStorage.StatusIndeterminate, expectedPref: true },
            ]
        }

        // Disabling first requires authentication (deliberate: the user must prove they
        // still know the password they will be left with), then deletes the credential
        // FIRST; the preference flips only when the deletion verifiably succeeded
        // (Success/NotFound) — never on error or indeterminate outcomes, since startup
        // trusts credential presence.
        function test_stayLoggedInDisable(data) {
            root.view.privacyStore.setStayLoggedIn(true)
            if (!data.noItem)
                root.secureStorageMock.creds[root.testKeyUid] = "dek:stored-dek-hex"
            root.secureStorageMock.deleteStatus = data.deleteStatus

            stayLoggedInSection().toggleStayLoggedIn(true) // switch was checked
            compare(root.secureStorageMock.deleteCalls.length, 0) // nothing before auth

            Global.authenticationResult(Constants.authenticationReason.disableStayLoggedIn,
                                        "password-1", "", root.testKeyUid, "")

            compare(root.secureStorageMock.deleteCalls.length, 1)
            compare(root.view.privacyStore.stayLoggedIn, data.expectedPref)
        }

        // A cancelled authentication leaves the feature enabled and the credential
        // untouched.
        function test_stayLoggedInDisableCancelledAuthKeepsCredential() {
            root.view.privacyStore.setStayLoggedIn(true)
            root.secureStorageMock.creds[root.testKeyUid] = "dek:stored-dek-hex"

            stayLoggedInSection().toggleStayLoggedIn(true)
            Global.authenticationResult(Constants.authenticationReason.disableStayLoggedIn,
                                        "", "", "", "") // cancelled

            compare(root.secureStorageMock.deleteCalls.length, 0)
            compare(root.secureStorageMock.creds[root.testKeyUid], "dek:stored-dek-hex")
            compare(root.view.privacyStore.stayLoggedIn, true)
        }

        // Password change with a stored silent credential: refreshed from the DEK-only
        // converter; the preference is untouched.
        function test_stayLoggedInRefreshOnPasswordChange() {
            root.view.privacyStore.setStayLoggedIn(true)
            root.secureStorageMock.creds[root.testKeyUid] = "dek:old-dek-hex"

            emitPasswordChanged(true)

            compare(root.secureStorageMock.setCalls.length, 1)
            compare(root.secureStorageMock.setCalls[0].credential, "dek:silent-dek-hex")
            compare(root.view.privacyStore.stayLoggedIn, true)
        }

        function test_stayLoggedInRefreshFailure_data() {
            return [
                { tag: "delete verified -> feature disabled", deleteStatus: SecureStorage.StatusSuccess, expectedPref: false },
                { tag: "delete failed -> preference kept", deleteStatus: SecureStorage.StatusGenericError, expectedPref: true },
                { tag: "delete indeterminate -> preference kept", deleteStatus: SecureStorage.StatusIndeterminate, expectedPref: true },
            ]
        }

        // Refresh failure deletes the stale credential; the preference is flipped OFF
        // only when the deletion verifiably succeeded.
        function test_stayLoggedInRefreshFailure(data) {
            root.view.privacyStore.setStayLoggedIn(true)
            root.secureStorageMock.creds[root.testKeyUid] = "dek:old-dek-hex"
            root.silentTransformResult = "" // conversion failure
            root.secureStorageMock.deleteStatus = data.deleteStatus

            emitPasswordChanged(true)

            compare(root.secureStorageMock.deleteCalls.length, 1)
            compare(root.view.privacyStore.stayLoggedIn, data.expectedPref)
        }

        // A password change NOT requested through this view's form (e.g. the app-level
        // encryption-migration flow, whose completion is handled by
        // ProfileEncryptionMigrationFlow) must be ignored: handling it here would
        // refresh the credentials from the EMPTY form fields and wrongly disable
        // biometrics and the stay-logged-in credential.
        function test_ignoresForeignPasswordChange() {
            root.keychainMock.creds[root.testKeyUid] = "old-password"
            root.view.privacyStore.setStayLoggedIn(true)
            root.secureStorageMock.creds[root.testKeyUid] = "dek:old-dek-hex"

            root.view.privacyStore.privacyModule.passwordChanged(true, "")

            compare(root.keychainMock.updateCalls.length, 0)
            compare(root.keychainMock.creds[root.testKeyUid], "old-password")
            compare(root.secureStorageMock.setCalls.length, 0)
            compare(root.secureStorageMock.deleteCalls.length, 0)
            compare(root.view.privacyStore.stayLoggedIn, true)
            compare(root.preference, "store")
        }
    }
}
