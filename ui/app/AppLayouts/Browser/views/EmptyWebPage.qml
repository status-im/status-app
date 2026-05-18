import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

import utils

import AppLayouts.Browser.panels

Rectangle {
    id: root

    property alias bookmarksModel: bookmarkListContainer.model
    property var determineRealURLFn: function(url){}

    signal setCurrentWebUrl(url url)
    signal addBookmarkRequested()
    signal favMenuRequested(var parent, point pos, string url, string name)

    color: Theme.palette.background

    Image {
        id: emptyPageImage

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 60
        width: 240
        height: 161

        source: Theme.palette.isDark ? Assets.png("browser/new_tab_dark") : Assets.png("browser/new_tab")
        cache: false
    }

    FavoritesList {
        id: bookmarkListContainer

        anchors.horizontalCenter: emptyPageImage.horizontalCenter
        anchors.top: emptyPageImage.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 30

        width: (parent.width < 600) ? (Math.floor(parent.width/cellWidth)*cellWidth) : 600

        determineRealURLFn: function(url) {
            return root.determineRealURLFn(url)
        }
        onSetCurrentWebUrl: url => root.setCurrentWebUrl(url)
        onAddBookmarkRequested: root.addBookmarkRequested()
        onFavMenuRequested: (parent, pos, url, name) => root.favMenuRequested(parent, pos, url, name)
    }
}
