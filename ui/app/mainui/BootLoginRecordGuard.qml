import QtQuick

import StatusQ

// The boot-login record outside the login flow: removed at app start when the feature is
// off (no boot login may follow a phone restart) and on Quit, kept current when a session
// is resumed.
QtObject {
    id: root

    required property SecureStorage secureStorage
    required property bool resumeAfterRestartEnabled

    // Quit keeps the "Stay logged in" credential (the next open logs in silently and
    // writes a new boot-login record) but must not resume after a phone restart
    function quit() : void {
        root.secureStorage.deleteBootLoginRecord()
    }

    // A resumed session (the app adopted a running login, e.g. a boot login) runs no
    // post-login tasks: `record` is the logged-in profile's current boot-login record from
    // Nim, "" when none may be kept. Written only next to the profile's credential.
    function keepCurrent(record: string) : void {
        if (record === "" || !root.resumeAfterRestartEnabled)
            return
        let keyUid = ""
        try {
            keyUid = JSON.parse(record).keyUid ?? ""
        } catch (e) {
            return
        }
        if (keyUid !== "" && root.secureStorage.hasCredential(keyUid) === SecureStorage.StatusSuccess)
            root.secureStorage.setBootLoginRecord(record)
    }

    Component.onCompleted: {
        if (!root.resumeAfterRestartEnabled)
            root.secureStorage.deleteBootLoginRecord()
    }
}
