import QtQuick
import QtTest

import StatusQ

import mainui

Item {
    id: root

    width: 600
    height: 500

    // Interleaved call log proving the delete-first ordering
    property var callLog: []

    Component {
        id: dialogComponent

        SignOutConfirmationDialog {
            parent: root

            secureStorage: SecureStorage {
                property int deleteStatus: SecureStorage.StatusSuccess
                property var deleteCalls: []

                function deleteCredential(account) {
                    deleteCalls.push(account)
                    root.callLog.push("delete:" + account)
                    return deleteStatus
                }
            }
            keyUid: "key-uid-1"

            onSignOutRequested: root.callLog.push("signout")
        }
    }

    TestCase {
        name: "SignOutConfirmationDialog"
        when: windowShown

        property var dialog: null

        function init() {
            root.callLog = []
        }

        function cleanup() {
            dialog = null
        }

        function test_confirm_data() {
            return [
                { tag: "verified deletion -> sign out", status: SecureStorage.StatusSuccess, signsOut: true },
                { tag: "nothing stored -> sign out", status: SecureStorage.StatusNotFound, signsOut: true },
                { tag: "generic error -> abort", status: SecureStorage.StatusGenericError, signsOut: false },
                { tag: "unavailable -> abort", status: SecureStorage.StatusUnavailable, signsOut: false },
                { tag: "indeterminate -> abort", status: SecureStorage.StatusIndeterminate, signsOut: false },
            ]
        }

        // Sign-out proceeds ONLY when the auto-login credential is verifiably gone
        // (deleted, or never present); any other outcome keeps the session and lets the
        // user retry. The credential deletion always runs first, with the correct key.
        function test_confirm(data) {
            dialog = createTemporaryObject(dialogComponent, root)
            verify(!!dialog)
            dialog.secureStorage.deleteStatus = data.status
            dialog.open()
            tryVerify(() => dialog.opened)

            dialog.confirmButtonClicked()

            compare(dialog.secureStorage.deleteCalls.length, 1)
            compare(dialog.secureStorage.deleteCalls[0], "key-uid-1")

            if (data.signsOut) {
                compare(root.callLog.join(","), "delete:key-uid-1,signout") // delete first
            } else {
                compare(root.callLog.join(","), "delete:key-uid-1") // session kept
                tryVerify(() => !dialog.opened) // dialog dismissed so the user can retry
            }
        }
    }
}
