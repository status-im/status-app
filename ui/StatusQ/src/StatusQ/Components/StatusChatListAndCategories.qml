import QtQuick

import StatusQ.Components
import StatusQ.Core

import SortFilterProxyModel

Item {
    id: root

    implicitHeight: statusChatList.height
    implicitWidth: statusChatList.width

    property alias highlightItem: statusChatList.highlightItem

    // When true the inner list is bounded to this item's height and scrolls
    // itself, building only viewport+cache delegates. When false (default)
    // the list expands to its full content height — hosts embed it in their
    // own scroll area (needed by drag-reorder, which addresses rows by index
    // across the whole list).
    property bool virtualized: false

    property var model: []
    property bool showCategoryActionButtons: false
    property bool showPopupMenu: true
    property alias sensor: sensor
    property bool draggableItems: false
    property bool draggableCategories: false

    property Component categoryPopupMenu
    property Component chatListPopupMenu
    property alias popupMenu: popupMenuSlot.sourceComponent

    signal chatItemSelected(string categoryId, string id)
    signal chatItemClicked(string id)
    signal chatItemUnmuted(string id)
    signal chatItemReordered(string categoryId, string chatId, int to)
    signal chatListCategoryReordered(string categoryId, int to)
    signal categoryAddButtonClicked(string id)
    signal toggleCollapsedCommunityCategory(string categoryId, bool collapsed)

    StatusMouseArea {
        id: sensor
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            if (mouse.button === Qt.RightButton && showPopupMenu && !!root.popupMenu) {
                popupMenuSlot.active = true
                popupMenuSlot.item.popup(mouse.x + 4, mouse.y + 6)
                return
            }
        }

        StatusChatList {
            objectName: "statusChatListAndCategoriesChatList"
            id: statusChatList
            width: parent.width
            height: root.virtualized ? sensor.height : implicitHeight
            virtualized: root.virtualized
            visible: statusChatList.model.count > 0
            onChatItemSelected: root.chatItemSelected(categoryId, id)
            onChatItemClicked: root.chatItemClicked(id)
            onChatItemUnmuted: root.chatItemUnmuted(id)
            onChatItemReordered: root.chatItemReordered(categoryId, chatId, to)
            onCategoryReordered: root.chatListCategoryReordered(categoryId, to)
            draggableItems: root.draggableItems
            showCategoryActionButtons: root.showCategoryActionButtons
            onCategoryAddButtonClicked: root.categoryAddButtonClicked(id)
            onToggleCollapsedCommunityCategory: root.toggleCollapsedCommunityCategory(categoryId, collapsed)

            model: SortFilterProxyModel {
                sourceModel: root.model
                filters: [
                    ValueFilter {
                        roleName: "shouldBeHiddenBecausePermissionsAreNotMet"
                        value: false
                    }
                ]
                sorters: [
                    RoleSorter {
                        roleName: "categoryPosition"
                        priority: 2 // Higher number === higher priority
                    },
                    RoleSorter {
                        roleName: "position"
                        priority: 1
                    }
                ]
            }

            popupMenu: root.chatListPopupMenu
            categoryPopupMenu: root.categoryPopupMenu
        }
    }

    Loader {
        id: popupMenuSlot
        // Built on first right click — see StatusChatList's menu slots
        active: false
    }
}
