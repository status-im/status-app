import QtQuick
import QtQuick.Controls

import StatusQ.Core.Utils
import StatusQ.Core.Theme

RecursiveStackView {
    id: root

    readonly property bool backAvailable:
        topLevelItem ? (topLevelItem.backAvailableHint ?? true) : false

    // Release focus and dismiss the keyboard unconditionally on every navigation,
    // instead of chasing down individual fields on individual pages.
    onCurrentItemChanged: {
        root.forceActiveFocus()
        Qt.inputMethod.hide()
    }

    QtObject {
        id: d

        readonly property int opacityDuration: 50
        readonly property int swipeDuration: 400
    }

    background: Rectangle {
        color: Theme.palette.background
    }

    pushEnter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0; to: 1
                duration: d.opacityDuration
                easing.type: Easing.InQuint
            }
            NumberAnimation {
                property: "x"
                from: (root.mirrored ? -0.3 : 0.3) * root.width; to: 0
                duration: d.swipeDuration
                easing.type: Easing.OutCubic
            }
        }
    }
    pushExit: Transition {
        NumberAnimation {
            property: "opacity"; from: 1; to: 0
            duration: d.opacityDuration
            easing.type: Easing.OutQuint
        }
    }
    popEnter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0; to: 1
                duration: d.opacityDuration
                easing.type: Easing.InQuint
            }
            NumberAnimation {
                property: "x"
                from: (root.mirrored ? -0.3 : 0.3) * -root.width; to: 0
                duration: d.swipeDuration; easing.type: Easing.OutCubic
            }
        }
    }
    popExit: pushExit
    replaceEnter: pushEnter
    replaceExit: pushExit
}
