import QtQuick

import StatusQ.Core

import utils

import "../controls"

StatusGridView {
    id: root

    property var determineRealURLFn: function(url){}

    signal setCurrentWebUrl(url url)
    signal addBookmarkRequested()
    signal favMenuRequested(var parent, point pos, string url, string name)

    cellWidth: 100
    cellHeight: 100

    delegate: BookmarkButton {
        required property var model
        readonly property bool isAddBookmarkButton: model.url === Constants.newBookmark

        text: model.name
        source: model.imageUrl || ""
        webUrl: root.determineRealURLFn(model.url)
        onClicked: function(mouse) {
            if (isAddBookmarkButton) {
                root.addBookmarkRequested()
            } else {
                root.setCurrentWebUrl(webUrl)
            }
        }
        onRightClicked: function(mouse) {
            if (isAddBookmarkButton)
                return
            root.favMenuRequested(this, Qt.point(mouse.x, mouse.y), model.url, model.name)
        }
    }
}
