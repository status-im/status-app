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

    property var keychainMock: null
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

                function changePassword(password, newPassword, rekey = false) {}

                function isProfileMigratedToDEKEncryption() {
                    return true
                }

                function getBiometricCredentialForStorage(keyUid, password) {
                    return root.transformResult
                }

                function setBiometricPreferenceNotNow() {
                    root.preference = "notNow"
                }
            }

            keychain: root.keychainMock
        }
    }

    TestCase {
        name: "ChangePasswordView_keychainFlow"
        when: windowShown

        function init() {
            root.preference = "store"
            root.transformResult = "dek:fresh-dek-hex"
            root.keychainMock = createTemporaryObject(mockedKeychainComponent, root)
            verify(!!root.keychainMock)
            root.keychainMock.deleteStatus = Keychain.StatusSuccess
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
    }
}
