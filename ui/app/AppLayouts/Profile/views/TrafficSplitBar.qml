import QtQuick

import StatusQ.Core.Theme

//! Two bars side by side in one track: sent, then received, against fullBytes.
Rectangle {
    id: root

    property real sent
    property real received
    property real fullBytes: 1
    property color sentColor: TrafficFormat.sentColor
    property color receivedColor: TrafficFormat.receivedColor

    implicitHeight: 8
    radius: height / 2
    color: Theme.palette.baseColor2
    clip: true

    Row {
        height: root.height
        Rectangle {
            width: root.width * Math.min(1, root.sent / Math.max(root.fullBytes, 1))
            height: root.height
            color: root.sentColor
        }
        Rectangle {
            width: root.width * Math.min(1, root.received / Math.max(root.fullBytes, 1))
            height: root.height
            color: root.receivedColor
        }
    }
}
