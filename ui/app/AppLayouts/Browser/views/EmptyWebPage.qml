import QtQuick
import QtWebEngine

import StatusQ.Core
import StatusQ.Core.Theme

import utils

import AppLayouts.Browser.panels

WebEngineView {
    id: root

    property alias bookmarksModel: bookmarkListContainer.model
    required property var favMenu
    required property var addFavModal
    property var determineRealURLFn: function(url){}

    signal setCurrentWebUrl(url url)

    backgroundColor: Theme.palette.background

    Item {
        anchors.fill: parent
        z: 54

        Image {
            id: emptyPageImage

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 60
            width: 294
            height: 294

            source: Assets.png("browser/pepehand")
            cache: false
        }

        FavoritesList {
            id: bookmarkListContainer

            anchors.horizontalCenter: emptyPageImage.horizontalCenter
            anchors.top: emptyPageImage.bottom
            anchors.topMargin: 30

            width: (parent.width < 700) ? (Math.floor(parent.width/cellWidth)*cellWidth) : 700
            height: parent.height - emptyPageImage.height - 20

            favMenu: root.favMenu
            addFavModal: root.addFavModal
            determineRealURLFn: function(url) {
                return root.determineRealURLFn(url)
            }
            setAsCurrentWebUrl: function(url) {
                root.setCurrentWebUrl(url)
            }
        }
    }
}

