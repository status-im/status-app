import QtQuick

// When the window's loading screen covers the session: from start until the first session
// content loads, and from an accepted relogin the user didn't request (the boot-login record
// refresh) until the next session's content loads. On the in-progress adopt path the login
// screen's content already ended it, so the relogin shows it again.
QtObject {
    id: root

    // () => bool: requests the relogin; false when it was ignored
    required property var relogin

    readonly property bool shown: d.shown
    // A relogin the user didn't request runs: the session end is not shown
    readonly property bool unrequestedRelogin: d.unrequestedRelogin

    function startUnrequestedRelogin() : bool {
        d.unrequestedRelogin = true
        if (!root.relogin()) {
            d.unrequestedRelogin = false
            return false
        }
        d.shown = true
        return true
    }

    function sessionContentLoaded() : void {
        d.shown = false
        d.unrequestedRelogin = false
    }

    readonly property QtObject _d: QtObject {
        id: d

        property bool shown: true
        property bool unrequestedRelogin: false
    }
}
