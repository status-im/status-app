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
    // (record) => void: the KeptCurrent rewrite of an adopted login's record
    // (BootLoginRecordGuard.keepCurrent), which stamps this version's versionCode
    required property var keepCurrent
    // () => bool: requests the relogin; false when it was ignored
    required property var relogin
    // () => void: links, shares and notification taps wait for the next session's appReady
    required property var holdIntake
    // () => void: the held ones go to the current session
    required property var releaseIntake

    // True once the relogin was accepted: this session ends and must not load the app (its
    // contentLoaded would end the window's loading screen and show the session end)
    readonly property bool reloginStarted: d.reloginStarted

    // On every adopt (logged in at start, or a boot login still in progress adopted by the
    // login screen), before its appReady: keeps `record` current. True when the stored record
    // was from another version (read before the rewrite): the intake is held, adoptFinished()
    // follows.
    function adoptStarted(record: string) : bool {
        d.reloginPending = root.enabled && root.secureStorage.isBootLoginRecordFromOtherVersion()
        root.keepCurrent(record)
        if (d.reloginPending)
            root.holdIntake()
        return d.reloginPending
    }

    // Once the adopt has finished, never from within it. True when the relogin was requested.
    function adoptFinished() : bool {
        if (!d.reloginPending)
            return false
        d.reloginPending = false
        console.warn("boot-login record from another app version: relogin to refresh it")
        if (root.relogin()) {
            d.reloginStarted = true
            return true
        }
        root.releaseIntake()
        return false
    }

    readonly property QtObject _d: QtObject {
        id: d

        property bool reloginPending: false
        property bool reloginStarted: false
    }
}
