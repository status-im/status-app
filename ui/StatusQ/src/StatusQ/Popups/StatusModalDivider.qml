pragma ComponentBehavior: Bound

import QtQuick

import StatusQ.Core.Theme

Column {
    spacing: 0

    property real topPadding: 0
    property real bottomPadding: 0
    property alias dividerColor: divider.color

    width: 480

    Item {
        id: topPaddingItem
        height: parent.topPadding
        width: parent.width
    }

    Rectangle {
        id: divider
        color: Theme.palette.baseColor2
        height: 1
        width: parent.width
    }

    Item {
        id: bottomPaddingItem
        height: parent.bottomPadding
        width: parent.width
    }
}
