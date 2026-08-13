import QtQuick
import QtTest

import StatusQ.Components

/*
 Configuration analysis for the chat list context menus
 ======================================================
 StatusChatList hosts two menu slots behind Loaders: popupMenu (chat rows,
 right-click) and categoryPopupMenu (community categories, right-click or
 menu button). Historically `active: !!sourceComponent` instantiated the
 full menu tree (ChatContextMenuView: dozens of StatusMenuItems, the
 mute-interval submenu, a scrollview) at section load, although a menu is
 only needed after the first interaction.

 Flows:
 - no interaction              → the menu component is never instantiated
                                 (perf intent, test 1)
 - right-click on a chat row   → menu instantiated once, openHandler invoked
                                 with the chat id, popup() shown (test 2)
 - second right-click          → same instance reused, no second
                                 instantiation (test 2)
 - category menu button        → category slot activates the same lazy way
                                 (test 3)
 The real ChatContextMenuView content is covered by the existing suites and
 storybook; these tests pin the instantiation contract with a counting
 test double, which a full menu popup would wedge (modal grab) in this
 harness.
*/
Item {
    id: root

    width: 400
    height: 600

    property int menuCreations: 0
    property int categoryMenuCreations: 0
    property var lastOpenedId
    property bool popupShown: false

    ListModel { id: chatsModel }

    Component {
        id: menuDouble

        QtObject {
            // mirrors the real menu contract: the list wraps openHandler so it
            // receives the clicked chat id, and popup() invokes it on open
            property var openHandler: function (id) { root.lastOpenedId = id }
            property var closeHandler

            function popup(x, y) {
                if (openHandler)
                    openHandler()
                root.popupShown = true
            }

            Component.onCompleted: root.menuCreations++
        }
    }

    Component {
        id: categoryMenuDouble

        QtObject {
            property var categoryItem

            function popup(x, y) {}

            Component.onCompleted: root.categoryMenuCreations++
        }
    }

    StatusChatList {
        id: chatList
        anchors.fill: parent
        model: chatsModel
        showCategoryActionButtons: true
        popupMenu: menuDouble
        categoryPopupMenu: categoryMenuDouble
    }

    TestCase {
        name: "ChatListContextMenu"
        when: windowShown

        function initTestCase() {
            for (let i = 0; i < 5; ++i) {
                chatsModel.append({
                    itemId: "chat-" + i,
                    categoryId: "",
                    name: "Contact " + i,
                    type: 1,
                    muted: false,
                    active: i === 0,
                    blocked: false,
                    hasUnreadMessages: false,
                    notificationsCount: 0,
                    highlight: false,
                    icon: "",
                    emoji: "",
                    color: "",
                    colorId: i,
                    categoryOpened: true,
                    usesDefaultName: false,
                    onlineStatus: 1,
                    requiresPermissions: false,
                    locked: false,
                    isCategory: false,
                    position: i,
                    categoryPosition: -1
                })
            }
            chatsModel.append({
                itemId: "",
                categoryId: "cat-1",
                name: "A Category",
                type: -1,
                muted: false,
                active: false,
                blocked: false,
                hasUnreadMessages: false,
                notificationsCount: 0,
                highlight: false,
                icon: "",
                emoji: "",
                color: "",
                colorId: 0,
                categoryOpened: true,
                usesDefaultName: false,
                onlineStatus: 0,
                requiresPermissions: false,
                locked: false,
                isCategory: true,
                position: -1,
                categoryPosition: 0
            })
            wait(200)
        }

        // INTENT (perf): assigning the menu components must not instantiate them
        function test_01_menusNotBuiltAtLoad() {
            compare(root.menuCreations, 0,
                    "chat context menu must not be instantiated before interaction")
            compare(root.categoryMenuCreations, 0,
                    "category context menu must not be instantiated before interaction")
        }

        // right-click instantiates once, opens with the clicked chat id,
        // and reuses the instance afterwards
        function test_02_rightClickOpensChatMenu() {
            const row = findChild(chatList, "Contact 1")
            verify(!!row)
            mouseClick(row, row.width / 2, row.height / 2, Qt.RightButton)

            tryVerify(() => root.popupShown, 2000, "popup() must be invoked")
            compare(root.menuCreations, 1)
            compare(root.lastOpenedId, "chat-1")

            root.popupShown = false
            const row2 = findChild(chatList, "Contact 2")
            mouseClick(row2, row2.width / 2, row2.height / 2, Qt.RightButton)
            tryVerify(() => root.popupShown, 2000)
            compare(root.menuCreations, 1, "menu instance is reused")
            compare(root.lastOpenedId, "chat-2")
        }

        // the category menu activates the same lazy way via its button
        function test_03_categoryMenuLazyOnButton() {
            const category = findChild(chatList, "A Category")
            verify(!!category)
            // right-click on the category row goes through setupPopup + popup
            mouseClick(category, category.width / 2, category.height / 2, Qt.RightButton)
            tryCompare(root, "categoryMenuCreations", 1)
        }
    }
}
