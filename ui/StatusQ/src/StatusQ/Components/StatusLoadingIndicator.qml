import QtQuick

import StatusQ.Core

StatusIcon {
    id: root

    icon: "loading"
    height: 20
    width: 20

    RotationAnimator {
        objectName: "spinnerAnimator"
        target: root
        from: 0
        to: 360
        duration: 1200
        running: root.visible
        loops: Animation.Infinite
    }
}
