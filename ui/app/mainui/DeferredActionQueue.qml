import QtQml

import StatusQ.Core.Utils as SQUtils

/**
  * Runs scheduled actions right away, or holds them while `blocked`.
  * Once unblocked, held actions run one at a time in scheduling order, each
  * waiting until `busy` is false. Scheduling a key that is already held
  * replaces its action and keeps its place.
  */
SQUtils.QObject {
    id: root

    property bool blocked: false
    property bool busy: false

    readonly property int pendingCount: d.keys.length

    function schedule(key: string, action) {
        if (!root.blocked) {
            action()
            return
        }
        if (!d.keys.includes(key))
            d.keys = d.keys.concat([key])
        d.actions[key] = action
    }

    onBlockedChanged: d.drain()
    onBusyChanged: d.drain()

    QtObject {
        id: d

        property var keys: []
        property var actions: ({})

        function drain() {
            while (!root.blocked && !root.busy && d.keys.length > 0) {
                const key = d.keys[0]
                const action = d.actions[key]
                delete d.actions[key]
                d.keys = d.keys.slice(1)
                action()
            }
        }
    }
}
