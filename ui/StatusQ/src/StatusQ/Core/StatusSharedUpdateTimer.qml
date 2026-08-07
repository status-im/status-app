pragma Singleton

import QtQml

QtObject {
    id: root

    readonly property alias secondsActive: d.secondsActive

    // Day-granularity counter for consumers whose output only changes when
    // the calendar day rolls over (e.g. relative timestamps) — depending on
    // secondsActive would re-evaluate them every second
    readonly property alias daysActive: d.daysActive

    signal triggered()

    readonly property Timer d: Timer {
        id: d
        property int secondsActive: 0
        property int daysActive: 0
        property int lastDay: new Date().getDate()

        interval: 1000
        running: Qt.application.state === Qt.ApplicationActive
        repeat: true

        function tick() {
            d.secondsActive++
            const day = new Date().getDate()
            if (day !== d.lastDay) {
                d.lastDay = day
                d.daysActive++
            }
            root.triggered()
        }

        onTriggered: tick()
        onRunningChanged: {
            if (running)
                tick()
        }
    }
}
