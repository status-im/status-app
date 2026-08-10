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
    // true: the list is height-bounded and scrolls itself; false: it expands
    // to its content and the host's scroll area scrolls. Must be explicit —
    // deriving it from height/contentHeight comparisons flaps while row
    // heights settle, and toggling Flickable.interactive mid-press cancels
    // the grab and eats the tap.
    property bool virtualized: false

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
        interactive: root.virtualized

        delegate: Loader {
            id: chatListDelegate
            objectName: model.name
            width: ListView.view.width
            height: rowVisible && item ? item.implicitHeight : 0

            // chat rows collapse with their category unless they demand
            // attention (active / unread / notifications)
            readonly property bool rowVisible: model.isCategory ||
                                               model.active ||
                                               (!model.muted && model.hasUnreadMessages) ||
                                               model.notificationsCount > 0 ||
                                               model.categoryOpened

            readonly property int visualIndex: index
            readonly property string chatId: model.itemId
            readonly property string categoryId: model.categoryId
            readonly property int position: model.position // needed for the DnD
            readonly property int categoryPosition: model.categoryPosition // needed for the DnD
            readonly property bool isCategory: model.isCategory

            // The drop/drag wrappers only exist for users who can reorder;
            // everyone else gets the bare row item
            sourceComponent: {
                if (root.draggableItems)
                    return draggableRowComponent
                return isCategory ? categoryRowComponent : chatRowComponent
            }

            // Each row instantiates only its own row type — a hidden twin of
            // the other type would double the per-row creation cost. The row
            // components are declared here so they share the delegate's model
            // context in both the plain and the draggable variant.
            Component {
                id: categoryRowComponent

                StatusChatListCategoryItem {
                    id: statusChatListCategoryItem
                    objectName: "categoryItem"

                    // driven by the draggable wrapper when present, which then
                    // also delivers the row clicks
                    property bool dragActive: false
                    property bool clickHandledByWrapper: false

                    StatusMouseArea {
                        anchors.fill: parent
                        // behind the toggle/menu/add buttons
                        z: -1
                        enabled: !statusChatListCategoryItem.clickHandledByWrapper
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        // left taps via TapHandler — MouseArea.clicked depends
                        // on the hover chain, which goes stale on panel
                        // roundtrips (see StatusChatListItem's sensor)
                        onClicked: {
                            if (mouse.button === Qt.RightButton)
                                statusChatListCategoryItem.clicked(mouse)
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            enabled: !statusChatListCategoryItem.clickHandledByWrapper
                            // default DragThreshold policy: passive grab, no
                            // hover-chain dependency
                            onTapped: (eventPoint, button) => {
                                statusChatListCategoryItem.clicked({
                                    button: Qt.LeftButton,
                                    x: eventPoint.position.x,
                                    y: eventPoint.position.y,
                                    modifiers: 0, accepted: true })
                            }
                        }
                    }

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
                    highlighted: dragActive
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
                }
            }

            Component {
                id: chatRowComponent

                StatusChatListItem {
                    id: statusChatListItem

                    readonly property bool isContactIcon: type === StatusChatListItem.Type.OneToOneChat && model.usesDefaultName
                    readonly property int iconWidth: 24
                    readonly property int iconHeight: 24

                    objectName: model.name
                    visible: chatListDelegate.rowVisible
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
                    sensor.enabled: clickHandledByWrapper ? dragActive : true
                    dragged: dragActive
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
            }

            Component {
                id: draggableRowComponent

                DropArea {
                    id: dropArea
                    implicitHeight: rowLoader.item ? rowLoader.item.implicitHeight : 0
                    keys: ["x-status-draggable-chat-list-item-and-categories"]

                    // draw the dragged row above its siblings
                    Binding {
                        target: chatListDelegate
                        property: "z"
                        value: draggableItem.dragActive ? 2 : 0
                    }

                    function setRowHighlighted(highlighted) {
                        if (rowLoader.item)
                            rowLoader.item.highlighted = highlighted
                    }

                    onEntered: function(drag) {
                        drag.accept();
                        setRowHighlighted(true);
                    }
                    onExited: setRowHighlighted(false)

                    onDropped: function(drop) {
                        setRowHighlighted(false);
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
                        readonly property bool isCategory: chatListDelegate.isCategory

                        id: draggableItem
                        width: parent.width
                        height: parent.height
                        // The ghost stays in its own DropArea: reparenting it
                        // mid-drag (into the ListView) makes the drag jump by
                        // the list's scene offset — rows away from the finger.
                        // The delegate's z is raised instead so the ghost
                        // draws above the other rows.
                        dragParent: dropArea
                        visualIndex: chatListDelegate.visualIndex
                        draggable: statusChatListItems.count > 1
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

                        Drag.keys: dropArea.keys

                        onClicked: function(mouse) {
                            if (rowLoader.item)
                                rowLoader.item.clicked(mouse);
                        }

                        actions: [
                            Loader {
                                id: rowLoader
                                Layout.fillWidth: true
                                sourceComponent: chatListDelegate.isCategory ? categoryRowComponent
                                                                             : chatRowComponent
                                onLoaded: item.clickHandledByWrapper = true
                            }
                        ]

                        Binding {
                            target: rowLoader.item
                            property: "dragActive"
                            value: draggableItem.dragActive
                        }
                    }
                }
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
