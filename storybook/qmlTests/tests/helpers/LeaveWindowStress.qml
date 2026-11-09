import QtQuick

/*
   Takes `count` animating delegates out of the window and puts them back,
   `run(toggles)` times. A Timer ticks on the animation clock, so each removal
   lands right after a sync, while the render thread advances animations.
*/
Loader {
    id: root

    property Component delegate
    property int count: 100
    property int columns: 10

    readonly property bool running: timer.running

    function run(toggles) {
        timer.remaining = toggles
        timer.start()
    }

    active: false
    sourceComponent: Grid {
        columns: root.columns

        Repeater {
            model: root.count
            delegate: root.delegate
        }
    }

    Timer {
        id: timer

        property int remaining: 0

        interval: 150
        repeat: true
        onTriggered: {
            root.active = !root.active
            if (--remaining <= 0)
                stop()
        }
    }
}
