import QtQuick

import StatusQ.Core.Theme

Rectangle {
    id: root

    property double dotsDiameter
    property int duration
    property double maxOpacity
    property color dotsColor

    width: root.dotsDiameter
    height: width
    radius: width / 2
    color: root.dotsColor

    SequentialAnimation {
        id: blinkingAnimation
        objectName: "dotBlinkAnimation"

        loops: Animation.Infinite
        running: root.visible
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: root.duration }
        NumberAnimation { target: root; property: "opacity"; to: root.maxOpacity; duration: root.duration }
    }
}
