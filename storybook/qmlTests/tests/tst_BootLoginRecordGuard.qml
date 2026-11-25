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
            property int recordWrites: 0

            function hasCredential(account) {
                return creds[account] !== undefined ? SecureStorage.StatusSuccess
                                                    : SecureStorage.StatusNotFound
            }
            function setBootLoginRecord(record) {
                recordWrites++
                bootLoginRecord = record
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

        readonly property string currentRecord: "{\"version\":1,\"keyUid\":\"uid_1\",\"loginRequest\":{}}"

        // A resumed session (e.g. the app opened after a boot login) runs no post-login
        // tasks: it must still leave a record for the next phone restart
        function test_resumedSessionWritesAMissingRecord() {
            const guard = createGuard(true)
            guard.secureStorage.bootLoginRecord = ""

            guard.keepCurrent(currentRecord)

            compare(guard.secureStorage.bootLoginRecord, currentRecord)
        }

        function test_resumedSessionRewritesAStaleRecord() {
            const guard = createGuard(true)

            guard.keepCurrent(currentRecord)

            compare(guard.secureStorage.recordWrites, 1)
            compare(guard.secureStorage.bootLoginRecord, currentRecord)
        }

        function test_resumedSessionWithoutCredentialWritesNoRecord() {
            const guard = createGuard(true)
            guard.secureStorage.bootLoginRecord = ""
            delete guard.secureStorage.creds["uid_1"]

            guard.keepCurrent(currentRecord)

            compare(guard.secureStorage.recordWrites, 0)
            compare(guard.secureStorage.bootLoginRecord, "")
        }

        // Stay logged in off, a keycard profile, the flag off or not Android: Nim sends ""
        function test_resumedSessionWithoutRecordKeepsTheStoredOne() {
            const guard = createGuard(true)

            guard.keepCurrent("")

            compare(guard.secureStorage.recordWrites, 0)
            compare(guard.secureStorage.bootLoginRecord, "{\"version\":1}")
        }

        function test_flagOffResumedSessionWritesNoRecord() {
            const guard = createGuard(false)

            guard.keepCurrent(currentRecord)

            compare(guard.secureStorage.recordWrites, 0)
        }
    }
}
