import QtQuick 2.15
import StatusQ.Controls 0.1
import StatusQ.Core.Utils as StatusQUtils

Item {
    id: root

    // Normalization distance for swipe progress (logical units). Set this to the drawer width.
    // If 0, native impl uses its internal heuristics.
    property real openDistance: 0

    // True while a swipe gesture is active (press+move until release/cancel).
    // Useful for consumers that want to show UI affordances during the gesture.
    property bool isSwipeActive: false

    // API: gesture deltas only (no absolute position inference).
    // `delta` and `velocity` are in logical pixels along the X axis.
    signal swipeStarted()
    signal swipeUpdated(real delta, real velocity)
    signal swipeEnded(real delta, real velocity, bool canceled)

    Loader {
        id: implLoader
        anchors.fill: parent

        sourceComponent: StatusQUtils.Utils.isMobile || StatusQUtils.Utils.isMacOS
                         ? nativeComponent
                         : qmlComponent
    }

    Component {
        id: nativeComponent
        NativeSwipeHandlerItem { anchors.fill: parent }
    }

    Component {
        id: qmlComponent
        NativeSwipeHandlerImpl { anchors.fill: parent }
    }

    Binding { target: implLoader.item; property: "visible"; value: root.visible; when: implLoader.item !== null }
    Binding { target: implLoader.item; property: "enabled"; value: root.enabled; when: implLoader.item !== null }
    Binding { target: implLoader.item; property: "openDistance"; value: root.openDistance; when: implLoader.item !== null }

    Connections {
        target: implLoader.item ?? null
        enabled: implLoader.item !== null && implLoader.status === Loader.Ready

        function onSwipeStarted() {
            root.isSwipeActive = true
            root.swipeStarted()
        }
        function onSwipeUpdated(delta, velocity) { root.swipeUpdated(delta, velocity) }
        function onSwipeEnded(delta, velocity, canceled) {
            root.isSwipeActive = false
            root.swipeEnded(delta, velocity, canceled)
        }
    }
}


