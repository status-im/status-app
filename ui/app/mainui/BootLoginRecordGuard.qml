import QtQuick

import StatusQ

// The boot-login record outside a session: removed at app start when the feature is off
// (no boot login may follow a phone restart) and on Quit.
QtObject {
    id: root

    required property SecureStorage secureStorage
    required property bool resumeAfterRestartEnabled

    // Quit keeps the "Stay logged in" credential (the next open logs in silently and
    // writes a new boot-login record) but must not resume after a phone restart
    function quit() : void {
        root.secureStorage.deleteBootLoginRecord()
    }

    Component.onCompleted: {
        if (!root.resumeAfterRestartEnabled)
            root.secureStorage.deleteBootLoginRecord()
    }
}
