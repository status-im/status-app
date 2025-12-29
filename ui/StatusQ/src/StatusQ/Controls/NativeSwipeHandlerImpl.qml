import QtQuick 2.15

Item {
    id: root

    // See NativeSwipeHandler.qml
    property real openDistance: 0

    // See NativeSwipeHandler.qml (delta/velocity-only API)
    signal swipeStarted()
    signal swipeUpdated(real delta, real velocity)
    signal swipeEnded(real delta, real velocity, bool canceled)

    QtObject {
        id: d
        property bool active: false
        property real startX: 0
        property real lastX: 0
        property real lastTime: 0
        property real lastDx: 0
        property real lastVx: 0

        function nowMs() { return Date.now() }

        function effectiveOpenDistance() {
            return root.openDistance > 0 ? root.openDistance : 280
        }

        function velocityPxPerSecStep(dx, dtMs) {
            const dt = Math.max(1, dtMs)
            return (dx / dt) * 1000.0
        }
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: false
        propagateComposedEvents: true

        onPressed: (mouse) => {
            d.active = true
            d.startX = mouse.x
            d.lastX = mouse.x
            d.lastTime = d.nowMs()
            d.lastDx = 0
            d.lastVx = 0
        }

        onPositionChanged: (mouse) => {
            if (!d.active) {
                mouse.accepted = false
                return
            }

            const dx = mouse.x - d.startX
            const stepDx = mouse.x - d.lastX
            const now = d.nowMs()
            const stepV = d.velocityPxPerSecStep(stepDx, now - d.lastTime)

            if (d.lastDx === 0 && d.lastVx === 0) {
                root.swipeStarted()
            }

            d.lastX = mouse.x
            d.lastTime = now
            d.lastDx = dx
            d.lastVx = stepV

            root.swipeUpdated(dx, stepV)
            mouse.accepted = true
        }

        onReleased: (mouse) => {
            if (!d.active) {
                mouse.accepted = false
                return
            }

            const dx = mouse.x - d.startX
            d.lastDx = dx
            d.active = false
            // Prefer instantaneous velocity; the average over the whole gesture is too low
            // for quick short flicks (and makes end decisions feel wrong).
            root.swipeEnded(dx, d.lastVx, false)
            mouse.accepted = true
        }

        onCanceled: {
            if (d.active) {
                d.active = false
                root.swipeEnded(d.lastDx, 0, true)
            }
        }
    }
}


