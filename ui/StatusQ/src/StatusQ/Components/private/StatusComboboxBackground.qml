pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core.Theme

Rectangle {
    id: root

    required property bool active // hovered or down

    border.width: 1
    border.color: Theme.palette.directColor7
    radius: Theme.radius
    color: root.active ? Theme.palette.directColor8 : "transparent"
    HoverHandler {
        cursorShape: root.enabled ? Qt.PointingHandCursor : undefined
    }
}
