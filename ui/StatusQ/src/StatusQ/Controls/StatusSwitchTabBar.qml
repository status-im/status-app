pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core.Theme

TabBar {
    id: root

    padding: 1

    contentItem: ListView {
        model: root.contentModel
        currentIndex: root.currentIndex
        clip: true
        spacing: root.spacing
        orientation: ListView.Horizontal
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.AutoFlickIfNeeded
        snapMode: ListView.SnapToItem
    }

    background: Rectangle {
        color: Theme.palette.statusSwitchTab.barBackgroundColor
        radius: Theme.radius
    }
}
