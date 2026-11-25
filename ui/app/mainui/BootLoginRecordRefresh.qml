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

    // True when the relogin was requested: the adopted session's UI is not loaded then.
    function reloginIfRecordFromOtherVersion() : bool {
        return root.enabled
                && root.secureStorage.isBootLoginRecordFromOtherVersion()
                && root.relogin()
    }
}
