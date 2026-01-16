/*
    Copyright (C) 2011 Jocelyn Turcotte <turcotte.j@gmail.com>

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public License
    along with this program; see the file COPYING.LIB.  If not, write to
    the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301, USA.
*/

import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Components

import utils
import shared.panels

import AppLayouts.Chat.adaptors

Rectangle {
    id: root

    property var model
    property Item delegate

    property alias suggestionsModel: suggestionsFilterAdaptor.model

    property string filter
    readonly property alias formattedPlainTextFilter: suggestionsFilterAdaptor.filter

    property int lastAtPosition: -1
    property int cursorPosition: 0

    property alias listView: listView
    property var inputField
    property bool shouldHide: false

    signal itemSelected(var item, int lastAtPosition, int lastCursorPosition)

    onFilterChanged: suggestionsFilterAdaptor.invalidateFilter()

    onFormattedPlainTextFilterChanged: {
        // We need to callLater because the sort needs to happen before setting the index
        Qt.callLater(function () {
            listView.currentIndex = 0
        })
    }

    onCursorPositionChanged: {
        if (shouldHide) {
            shouldHide = false
        }
    }

    function hide() {
        shouldHide = true
    }

    function selectCurrentItem() {
        root.itemSelected(listView.model.get(listView.currentIndex), root.lastAtPosition, root.cursorPosition)
    }

    onVisibleChanged: {
        if (visible && listView.currentIndex === -1) {
            // If the previous selection was made using the mouse, the currentIndex was changed to -1
            // We change it back to 0 so that it can be used to select using the keyboard
            listView.currentIndex = 0
        }
        if (visible && !SQUtils.Utils.isMobile) {
            listView.forceActiveFocus();
        }
    }

    z: parent.z + 100
    visible: !shouldHide && filter.length > 0 && suggestionsModel.count > 0 && root.lastAtPosition > -1
    height: Math.min(400, listView.contentHeight + Theme.padding)

    opacity: visible ? 1.0 : 0
    Behavior on opacity {
        NumberAnimation { }
    }

    color: Theme.palette.background
    radius: Theme.radius

    layer.enabled: true
    layer.effect: DropShadow {
        width: root.width
        height: root.height
        x: root.x
        y: root.y + 10
        visible: root.visible
        source: root
        horizontalOffset: 0
        verticalOffset: 2
        radius: 10
        samples: 15
        color: "#22000000"
    }

    SuggestionsFilterAdaptor {
        id: suggestionsFilterAdaptor

        sourceModel: root.model
        filter: getFilter().substring(root.lastAtPosition + 1, root.cursorPosition).replace(/\*/g, "")

        function invalidateFilter() {
            root.lastAtPosition = -1

            const filter = getFilter()
            if (filter === "") {
                return
            }

            for (let c = root.cursorPosition === 0 ? 0 : (root.cursorPosition-1); c >= 0; c--) {
                if (filter.charAt(c) === "@") {
                    root.lastAtPosition = c
                    break
                }
            }
        }

        function getFilter() {
            if (root.filter.length === 0 || root.cursorPosition === 0) {
                return ""
            }

            return SQUtils.StringUtils.plainText(root.filter)
        }
    }

    StatusListView {
        id: listView
        objectName: "suggestionBoxList"
        keyNavigationEnabled: true
        anchors.fill: parent
        anchors.margins: Theme.halfPadding
        Keys.priority: Keys.AfterItem
        Keys.forwardTo: root.inputField
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.hide();
            } else if (event.key !== Qt.Key_Up && event.key !== Qt.Key_Down) {
                event.accepted = false;
            }
        }
        model: root.suggestionsModel

        delegate: Rectangle {
            id: itemDelegate
            objectName: model.preferredDisplayName
            color: ListView.isCurrentItem ? Theme.palette.backgroundHover : StatusColors.transparent
            width: ListView.view.width
            height: 42
            radius: Theme.radius

            StatusUserImage {
                id: accountImage
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.smallPadding
                imageWidth: 32
                imageHeight: 32

                name: model.preferredDisplayName
                usesDefaultName: model.usesDefaultName
                userColor: Utils.colorForColorId(root.Theme.palette, model.colorId)
                image: model.icon
                interactive: false
            }

            StyledText {
                text: model.preferredDisplayName
                color: Theme.palette.textColor
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: accountImage.right
                anchors.leftMargin: Theme.smallPadding
            }

            StatusMouseArea {
                id: mouseArea
                cursorShape: Qt.PointingHandCursor
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    listView.currentIndex = index
                }
                onClicked: {
                    root.itemSelected(model, root.lastAtPosition, root.cursorPosition)
                }
            }
        }
    }
}
