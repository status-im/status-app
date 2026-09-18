import QtQuick

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Utils

import SortFilterProxyModel

Item {
    id: root

    implicitWidth: statusChatList.implicitWidth

    property alias highlightItem: statusChatList.highlightItem
    property alias footer: statusChatList.footer

    property var model: []
    property bool showCategoryActionButtons: false
    property bool showPopupMenu: true
    property alias sensor: sensor
    property bool draggableItems: false
    property bool showThreads: true
    property bool isMobile: Utils.isMobile

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
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton && root.showPopupMenu && !!root.popupMenu) {
                popupMenuSlot.item.popup(mouse.x + 4, mouse.y + 6)
                return
            }
        }

        StatusChatList {
            objectName: "statusChatListAndCategoriesChatList"
            id: statusChatList
            width: parent.width
            height: parent.height
            onChatItemSelected: (categoryId, id) => root.chatItemSelected(categoryId, id)
            onChatItemClicked: id => root.chatItemClicked(id)
            onChatItemUnmuted: id => root.chatItemUnmuted(id)
            onChatItemReordered: (categoryId, chatId, to) => root.chatItemReordered(categoryId, chatId, to)
            onCategoryReordered: (categoryId, to) => root.chatListCategoryReordered(categoryId, to)
            draggableItems: root.draggableItems
            showCategoryActionButtons: root.showCategoryActionButtons
            showThreads: root.showThreads
            isMobile: root.isMobile
            onCategoryAddButtonClicked: id => root.categoryAddButtonClicked(id)
            onToggleCollapsedCommunityCategory: (categoryId, collapsed) => root.toggleCollapsedCommunityCategory(categoryId, collapsed)

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
        active: !!sourceComponent
    }
}
