import QtQml

import StatusQ.Core.Utils as SQUtils

/**
  * Runs scheduled actions right away, or holds them while `blocked` and runs
  * them in scheduling order once unblocked. Scheduling a key that is already
  * held replaces its action and keeps its place.
  */
SQUtils.QObject {
    id: root

    property bool blocked: false

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

    onBlockedChanged: d.flush()

    QtObject {
        id: d

        property var keys: []
        property var actions: ({})

        // An action may block the queue again; the rest then stays held
        function flush() {
            while (!root.blocked && d.keys.length > 0) {
                const key = d.keys[0]
                const action = d.actions[key]
                delete d.actions[key]
                d.keys = d.keys.slice(1)
                action()
            }
        }
    }
}
