import QtQuick
import QtTest

import StatusQ

import mainui

Item {
    id: root

    Component {
        id: storageComponent

        SecureStorage {
            property var creds: ({ "uid_1": "dek:" + "a".repeat(64) })
            property string bootLoginRecord: "{\"version\":1}"
            property int credentialDeleteCalls: 0

            function deleteCredential(account) {
                credentialDeleteCalls++
                delete creds[account]
                return SecureStorage.StatusSuccess
            }
            function deleteBootLoginRecord() {
                if (bootLoginRecord === "")
                    return SecureStorage.StatusNotFound
                bootLoginRecord = ""
                return SecureStorage.StatusSuccess
            }
        }
    }

    Component {
        id: guardComponent

        BootLoginRecordGuard {}
    }

    TestCase {
        name: "BootLoginRecordGuard"

        function createGuard(flagOn) {
            const storage = createTemporaryObject(storageComponent, root)
            const guard = createTemporaryObject(guardComponent, root, {
                secureStorage: storage,
                resumeAfterRestartEnabled: flagOn
            })
            verify(!!guard)
            return guard
        }

        function test_flagOffRemovesTheRecordAtAppStart() {
            const guard = createGuard(false)
            compare(guard.secureStorage.bootLoginRecord, "")
        }

        function test_flagOnKeepsTheRecordAtAppStart() {
            const guard = createGuard(true)
            compare(guard.secureStorage.bootLoginRecord, "{\"version\":1}")
        }

        function test_quitRemovesTheRecordButKeepsTheCredential() {
            const guard = createGuard(true)

            guard.quit()

            compare(guard.secureStorage.bootLoginRecord, "")
            compare(guard.secureStorage.credentialDeleteCalls, 0)
            compare(guard.secureStorage.creds["uid_1"], "dek:" + "a".repeat(64))
        }
    }
}
