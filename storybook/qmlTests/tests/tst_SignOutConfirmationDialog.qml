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

            // The per-profile auto-login suppression store (localAppSettings in the app);
            // the real setter flushes to disk and reports whether the marker persisted.
            appSettings: QtObject {
                property bool suppressionResult: true
                function setAutoLoginSuppressed(keyUid, value) {
                    root.callLog.push("suppress:" + keyUid + ":" + value)
                    return suppressionResult
                }
            }

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
                { tag: "verified deletion", status: SecureStorage.StatusSuccess, suppresses: false, signsOut: true },
                { tag: "nothing stored", status: SecureStorage.StatusNotFound, suppresses: false, signsOut: true },
                { tag: "no backend on this platform", status: SecureStorage.StatusNotSupported, suppresses: false, signsOut: true },
                { tag: "generic error", status: SecureStorage.StatusGenericError, suppresses: true, signsOut: true },
                { tag: "unavailable (incl. inaccessible keychain)", status: SecureStorage.StatusUnavailable, suppresses: true, signsOut: true },
                { tag: "indeterminate", status: SecureStorage.StatusIndeterminate, suppresses: true, signsOut: true },
                { tag: "suppression also unverified -> abort", status: SecureStorage.StatusUnavailable, suppresses: true, suppressionFails: true, signsOut: false },
            ]
        }

        // Sign-out proceeds only after the credential is either verifiably gone
        // (deleted, never present, or NotSupported — the stub backend, where no build
        // could ever have stored one) or startup auto-login has been VERIFIABLY
        // suppressed on disk for the profile (the process may hard-exit right after).
        // When neither can be confirmed, the session is kept so the user can retry.
        // The deletion always runs first, with the correct key.
        function test_confirm(data) {
            dialog = createTemporaryObject(dialogComponent, root)
            verify(!!dialog)
            dialog.secureStorage.deleteStatus = data.status
            dialog.appSettings.suppressionResult = !data.suppressionFails
            dialog.open()
            tryVerify(() => dialog.opened)

            dialog.confirmButtonClicked()

            compare(dialog.secureStorage.deleteCalls.length, 1)
            compare(dialog.secureStorage.deleteCalls[0], "key-uid-1")

            let expected = "delete:key-uid-1"
            if (data.suppresses)
                expected += ",suppress:key-uid-1:true"
            if (data.signsOut)
                expected += ",signout"
            compare(root.callLog.join(","), expected)

            if (!data.signsOut)
                tryVerify(() => !dialog.opened) // session kept; dialog dismissed for retry
        }
    }
}
