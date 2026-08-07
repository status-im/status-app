import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Components
import StatusQ.Controls

Item {
    id: root

    implicitWidth: 288
    implicitHeight: statusChatListItems.contentHeight

    property string categoryId: ""
    property var model: null
    property bool draggableItems: false
    property bool highlightItem: true
    property bool showCategoryActionButtons: false

    property alias statusChatListItems: statusChatListItems

    property alias popupMenu: popupMenuSlot.sourceComponent
    property alias categoryPopupMenu: categoryPopupMenuSlot.sourceComponent

    signal chatItemSelected(string categoryId, string id)
    signal chatItemClicked(string id)
    signal chatItemUnmuted(string id)
    signal categoryReordered(string categoryId, int to)
    signal chatItemReordered(string categoryId, string chatId, int to)
    signal categoryAddButtonClicked(string id)
    signal toggleCollapsedCommunityCategory(string categoryId, bool collapsed)

    StatusListView {
        id: statusChatListItems
        width: parent.width
        height: parent.height
        objectName: "chatListItems"
        model: root.model
        spacing: 0
        interactive: height !== contentHeight

        delegate: DropArea {
            id: chatListDelegate
            objectName: model.name
            width: ListView.view.width
            height: isCategory ? statusChatListCategoryItem.height : statusChatListItem.height
            keys: ["x-status-draggable-chat-list-item-and-categories"]

            readonly property int visualIndex: index
            readonly property string chatId: model.itemId
            readonly property string categoryId: model.categoryId
            readonly property int position: model.position // needed for the DnD
            readonly property int categoryPosition: model.categoryPosition // needed for the DnD
            readonly property bool isCategory: model.isCategory
            readonly property Item item: isCategory ? draggableItem.actions[0] : draggableItem.actions[1]

            onEntered: function(drag) {
                drag.accept();
                statusChatListCategoryItem.highlighted = true;
                statusChatListItem.highlighted = true;
            }
            onExited: {
                statusChatListCategoryItem.highlighted = false;
                statusChatListItem.highlighted = false;
            }

            onDropped: function(drop) {
                statusChatListCategoryItem.highlighted = false;
                statusChatListItem.highlighted = false;
                const from = drop.source.visualIndex;
                const to = chatListDelegate.visualIndex;
                if (to === from)
                    return;
                if (drop.source.isCategory) {
                    root.categoryReordered(
                        statusChatListItems.itemAtIndex(from).categoryId,
                        statusChatListItems.itemAtIndex(to).categoryPosition
                    );

                } else {
                    root.chatItemReordered(
                        statusChatListItems.itemAtIndex(to).categoryId,
                        statusChatListItems.itemAtIndex(from).chatId,
                        statusChatListItems.itemAtIndex(to).position,
                    );
                }
            }

            StatusDraggableListItem {
                readonly property bool isCategory: model.isCategory

                id: draggableItem
                width: parent.width
                height: visible ? (isCategory ? statusChatListCategoryItem.implicitHeight : statusChatListItem.implicitHeight) : 0
                dragParent: root.draggableItems ? statusChatListItems : null
                visualIndex: chatListDelegate.visualIndex
                draggable: (root.draggableItems && (statusChatListItems.count > 1))
                horizontalPadding: 0
                verticalPadding: 0
                icon.width: 0
                icon.height: 0
                spacing: 0
                topInset: 0
                bottomInset: 0

                showDragHandle: Utils.isMobile
                dragByHandleOnly: Utils.isMobile
                drawBackgroundBorder: false

                Drag.keys: chatListDelegate.keys

                onClicked: function(mouse) {
                    if (draggableItem.isCategory) {
                        statusChatListCategoryItem.clicked(mouse);
                    } else {
                        statusChatListItem.clicked(mouse);
                    }
                }

                actions: [
                   StatusChatListCategoryItem {
                        id: statusChatListCategoryItem
                        objectName: "categoryItem"
                        Layout.fillWidth: true
                        visible: draggableItem.isCategory

                        function setupPopup() {
                            categoryPopupMenuSlot.active = true
                            categoryPopupMenuSlot.item.categoryItem = model
                        }
                        Connections {
                            enabled: categoryPopupMenuSlot.active && statusChatListCategoryItem.highlighted
                            target: categoryPopupMenuSlot.item
                            function onClosed() {
                                statusChatListCategoryItem.highlighted = false
                                statusChatListCategoryItem.menuButton.highlighted = false
                            }
                        }
                        text: model.name
                        opened: model.categoryOpened
                        highlighted: draggableItem.dragActive
                        showAddButton: showCategoryActionButtons
                        showMenuButton: !!root.popupMenu
                        hasUnreadMessages: model.hasUnreadMessages
                        muted: model.muted
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton && showCategoryActionButtons && !!root.categoryPopupMenu) {
                                statusChatListCategoryItem.setupPopup()
                                highlighted = true;
                                categoryPopupMenuSlot.item.popup()
                            } else if (mouse.button === Qt.LeftButton) {
                                // We pass the value for collapsed that we want
                                // So if opened == true, we want opened == false -> we pass collapsed = true
                                root.toggleCollapsedCommunityCategory(model.categoryId, statusChatListCategoryItem.opened)
                            }
                        }
                        onToggleButtonClicked: {
                            root.toggleCollapsedCommunityCategory(model.categoryId, statusChatListCategoryItem.opened)
                        }
                        onMenuButtonClicked: {
                            statusChatListCategoryItem.setupPopup()
                            highlighted = true
                            menuButton.highlighted = true
                            categoryPopupMenuSlot.item.popup()
                        }
                        onAddButtonClicked: {
                            root.categoryAddButtonClicked(categoryId)
                        }
                    },
                    StatusChatListItem {
                        id: statusChatListItem

                        readonly property bool isContactIcon: type === StatusChatListItem.Type.OneToOneChat && model.usesDefaultName
                        readonly property int iconWidth: 24
                        readonly property int iconHeight: 24

                        objectName: model.name
                        Layout.fillWidth: true
                        height: visible ? implicitHeight : 0
                        visible: !draggableItem.isCategory &&
                            (
                                model.active ||
                                (!model.muted && model.hasUnreadMessages) || // Show channel if it has unread messages but not muted
                                model.notificationsCount > 0 || // unless it's a notification (mentions, replies)
                                model.categoryOpened
                            )
                        chatId: model.itemId
                        categoryId: model.categoryId
                        name: model.name
                        type: model.type ?? StatusChatListItem.Type.CommunityChat
                        muted: model.muted
                        hasUnreadMessages: model.hasUnreadMessages
                        notificationsCount: model.notificationsCount
                        highlightWhenCreated: !!model.highlight
                        selected: (model.active && root.highlightItem)

                        asset.isImage: !!model.icon
                        asset.emoji: !!model.emoji ? model.emoji : ""
                        asset.color: isContactIcon ? Theme.palette.indirectColor2 : (!!model.color ? model.color : Theme.palette.userCustomizationColors[model.colorId])
                        asset.bgColor: isContactIcon ? Theme.palette.userCustomizationColors[model.colorId] : "transparent"
                        asset.name: {
                            if (asset.isImage) {
                                return model.icon
                            }
                            if (isContactIcon) {
                                return "contact"
                            }
                            return ""
                        }
                        asset.width: iconWidth
                        asset.height: iconHeight
                        asset.bgRadius: iconWidth / 2
                        asset.bgWidth: iconWidth
                        asset.bgHeight: iconHeight

                        onlineStatus: !!model.onlineStatus ? model.onlineStatus : StatusChatListItem.OnlineStatus.Inactive
                        sensor.enabled: draggableItem.dragActive
                        dragged: draggableItem.dragActive
                        requiresPermissions: model.requiresPermissions
                        locked: model.locked
                        onClicked: function(mouse) {
                            highlightWhenCreated = false

                            if (mouse.button === Qt.RightButton && !!root.popupMenu) {
                                statusChatListItem.highlighted = true

                                popupMenuSlot.active = true
                                const originalOpenHandler = popupMenuSlot.item.openHandler
                                const originalCloseHandler = popupMenuSlot.item.closeHandler

                                popupMenuSlot.item.openHandler = function () {
                                    if (!!originalOpenHandler) {
                                        originalOpenHandler(statusChatListItem.chatId)
                                    }
                                }

                                popupMenuSlot.item.closeHandler = function () {
                                    if (statusChatListItem) {
                                        statusChatListItem.highlighted = false
                                    }
                                    if (!!originalCloseHandler) {
                                        originalCloseHandler()
                                    }
                                }

                                const p = statusChatListItem.mapToItem(root, mouse.x, mouse.y)

                                popupMenuSlot.item.popup(p.x + 4, p.y + 6)
                                popupMenuSlot.item.openHandler = originalOpenHandler
                                return
                            }
                            if (!statusChatListItem.selected) {
                                root.chatItemSelected(statusChatListItem.categoryId, statusChatListItem.chatId)
                            }
                            root.chatItemClicked(statusChatListItem.chatId)
                        }

                        onUnmute: root.chatItemUnmuted(statusChatListItem.chatId)
                    }
                ]
            }
        }
    }

    // The menus instantiate on first use (right click / menu button) — an
    // assigned sourceComponent alone must not build the full menu tree at
    // list creation. Activation is synchronous, so `.item` is valid right
    // after setting `active`.
    Loader {
        id: popupMenuSlot
        active: false
    }

    Loader {
        id: categoryPopupMenuSlot
        active: false
    }
}
