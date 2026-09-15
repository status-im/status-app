pragma Singleton

import QtQml

QtObject {
    id: root

    readonly property alias secondsActive: d.secondsActive

    // Advances once per local calendar-day boundary, derived from the same 1s tick.
    // Bind to this instead of `secondsActive` for day-granular values (relative
    // timestamps): they can only change at midnight, so a per-second dependency
    // re-evaluates them ~86400x more often than the value can actually move.
    readonly property alias daysActive: d.daysActive

    signal triggered()

    readonly property Timer d: Timer {
        id: d
        property int secondsActive: 0
        property int daysActive: 0
        // Midnight of the day the last tick landed on, in local time (the same
        // day boundary LocaleUtils.daysTo() uses).
        property double dayStart: d.localDayStart()

        function localDayStart() {
            const now = new Date()
            now.setHours(0, 0, 0, 0)
            return now.getTime()
        }

        function tick() {
            d.secondsActive++
            const today = d.localDayStart()
            if (today !== d.dayStart) {
                d.dayStart = today
                d.daysActive++
            }
            root.triggered()
        }

        interval: 1000
        running: Qt.application.state === Qt.ApplicationActive
        repeat: true
        onTriggered: d.tick()
        onRunningChanged: {
            if (running)
                d.tick()
        }
    }
}
