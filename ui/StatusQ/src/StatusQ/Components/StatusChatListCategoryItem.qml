pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

Control {
    id: root

    implicitWidth: visible ? 288 : 0
    implicitHeight: visible ? 34 : 0

    horizontalPadding: Theme.halfPadding

    property string text
    property bool opened: true
    property bool highlighted: false
    property bool showActionButtons: false
    property bool showMenuButton: showActionButtons
    property bool showAddButton: showActionButtons
    property bool hasUnreadMessages: false
    property bool muted: false
    property alias addButton: addButton
    property alias menuButton: menuButton
    property alias toggleButton: toggleButton

    signal clicked(var mouse)
    signal addButtonClicked(var mouse)
    signal menuButtonClicked(var mouse)
    signal toggleButtonClicked(var mouse)

    background: Rectangle {
        color: (hoverHandler.hovered || root.highlighted) ? Theme.palette.baseColor2 : "transparent"
        radius: Theme.radius
    }

    contentItem: Item {
        HoverHandler {
            id: hoverHandler
            cursorShape: Qt.PointingHandCursor
        }

        StatusBaseText {
            width: Math.min(implicitWidth, parent.width)
            anchors.verticalCenter: parent.verticalCenter
            font.weight: root.hasUnreadMessages ? Font.Bold : Font.Medium
            elide: Text.ElideRight
            color: {
                if (root.muted && !hoverHandler.hovered && !root.highlighted) {
                    return Theme.palette.directColor5
                }
                if (root.hasUnreadMessages || root.highlighted || hoverHandler.hovered) {
                    return Theme.palette.directColor1
                }
                return Theme.palette.directColor4
            }

            text: root.text
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            StatusChatListCategoryItemButton {
                id: addButton
                objectName: "categoryItemButtonAdd"
                icon.name: "add"
                icon.width: 20
                visible: (root.showAddButton && (hoverHandler.hovered || root.highlighted))
                onClicked: root.addButtonClicked(mouse)
                tooltip.text: qsTr("Add channel inside category")
            }
            StatusChatListCategoryItemButton {
                id: menuButton
                objectName: "categoryItemButtonMore"
                icon.name: "more"
                icon.width: 21
                visible: (root.showMenuButton && (hoverHandler.hovered || root.highlighted))
                onClicked: root.menuButtonClicked(mouse)
                tooltip.text: qsTr("More")
            }
            StatusChatListCategoryItemButton {
                id: toggleButton
                objectName: "categoryItemButtonToggle"
                icon.name: "chevron-down"
                icon.width: 18
                icon.rotation: root.opened ? 0 : 270
                onClicked: root.toggleButtonClicked(mouse)
            }
        }
    }
}

