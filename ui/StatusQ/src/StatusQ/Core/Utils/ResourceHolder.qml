import QtQml

// Holds the resource under `key` while it exists and is active. It requests an
// acquire on activation and a release on deactivation, on a key change and on
// destruction, so every acquire request is paired with exactly one release.
QObject {
    id: root

    property string key
    property bool active: true

    // turns true after acquireRequested and false after releaseRequested: it is
    // false inside the acquire handler and true inside the release handler
    readonly property alias holding: d.holding

    signal acquireRequested(string key)
    signal releaseRequested(string key)

    // handlers, not a binding: a release handler may change `key` or `active`
    // and sync again from within
    onKeyChanged: d.sync()
    onActiveChanged: d.sync()

    QtObject {
        id: d

        property bool completed
        property string heldKey
        // updated only after the matching request, so holdingChanged handlers
        // never run between taking the key and requesting it
        property bool holding

        function wantedKey() {
            return completed && root.active ? root.key : ""
        }

        function sync() {
            const wanted = wantedKey()
            if (heldKey === wanted)
                return
            release()
            // a nested sync from the release handler already settled it
            if (heldKey !== "" || wantedKey() !== wanted)
                return
            heldKey = wanted
            if (wanted === "")
                return
            root.acquireRequested(wanted)
            holding = heldKey !== ""
        }

        function release() {
            if (heldKey === "")
                return
            const key = heldKey
            heldKey = ""
            root.releaseRequested(key)
            holding = heldKey !== ""
        }
    }

    Component.onCompleted: {
        d.completed = true
        d.sync()
    }
    Component.onDestruction: {
        // a release handler changing `key` must not acquire again
        d.completed = false
        d.release()
    }
}
