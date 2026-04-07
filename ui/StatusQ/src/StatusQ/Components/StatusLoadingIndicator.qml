pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core

StatusIcon {
    id: root

    icon: "loading"
    height: 20
    width: 20

    RotationAnimator {
        target: root
        from: 0
        to: 360
        duration: 1200
        running: visible
        loops: Animation.Infinite
    }
}
