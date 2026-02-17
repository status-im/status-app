import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls

import utils

Rectangle {
    id: root

    property alias bookmarkModel: bookmarkList.model

    property bool currentTabIncognito: false

    signal addBookmarkRequested()
    signal setAsCurrentWebUrl(url url)
    signal openInNewTab(url url)
    signal favMenuRequested(var parent, point pos, string url, string name)

    color: root.currentTabIncognito ?
               Theme.palette.privacyColors.primary:
               Theme.palette.background

    StatusListView {
        id: bookmarkList
        anchors.fill: parent
        anchors.leftMargin: Theme.halfPadding
        anchors.rightMargin: Theme.halfPadding
        spacing: Theme.halfPadding
        orientation : ListView.Horizontal
        delegate: StatusFlatButton {
            id: favoriteBtn
            size: StatusBaseButton.Size.Small
            icon.source: model.imageUrl
            icon.width: 24
            icon.height: 24
            // Limit long named tabs. StatusFlatButton is not well-behaved control
            //  implicitWidth doesn't work. Also avoid breaking visualization by escaping HTML
            text: SQUtils.StringUtils.escapeHtml(Utils.elideIfTooLong(name, 40))

            readonly property bool isAddBookmarkButton: model.url === Constants.newBookmark

            onClicked: {
                if (isAddBookmarkButton)
                    root.addBookmarkRequested()
                else
                    root.setAsCurrentWebUrl(model.url)
            }
            ContextMenu.onRequested: function(pos) {
                if (favoriteBtn.isAddBookmarkButton)
                    return
                root.favMenuRequested(this, pos, model.url, model.name)
            }
            onPressAndHold: {
                if (favoriteBtn.isAddBookmarkButton)
                    return
                root.favMenuRequested(this, Qt.point(pressX, pressY), model.url, model.name)
            }

            TapHandler {
                acceptedButtons: Qt.MiddleButton
                onTapped: function(eventPoint) {
                    eventPoint.accepted = true
                    root.openInNewTab(model.url)
                }
            }
        }
    }
}
