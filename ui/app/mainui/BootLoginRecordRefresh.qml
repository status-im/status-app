import QtQuick

import StatusQ

// After the UI adopts a session, a boot-login record written by another app version (the
// boot login replayed it after an update) is refreshed by one silent relogin
// (AutoLoginPolicy.AllowOnce): its login request is built by this version and writes a new
// record. Android only: elsewhere the secure storage never reports one.
QtObject {
    id: root

    required property bool enabled
    required property SecureStorage secureStorage
    // () => bool: requests the relogin; false when it was ignored
    required property var relogin

    // When the UI adopts a session. True when the record is from another version: the
    // adopted session's UI is not loaded, adoptFinished() follows.
    function adoptStarted() : bool {
        d.reloginPending = root.enabled && root.secureStorage.isBootLoginRecordFromOtherVersion()
        return d.reloginPending
    }

    // Once the adopt has finished, never from within it. True when the relogin was requested.
    function adoptFinished() : bool {
        if (!d.reloginPending)
            return false
        d.reloginPending = false
        console.warn("boot-login record from another app version: relogin to refresh it")
        return root.relogin()
    }

    readonly property QtObject _d: QtObject {
        id: d

        property bool reloginPending: false
    }
}
