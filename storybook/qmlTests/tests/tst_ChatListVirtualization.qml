import QtQuick
import QtTest

import StatusQ.Components

// Minimal repro: does StatusChatList virtualize its rows when given a
// bounded height, or does it instantiate a delegate per model row?
Item {
    id: root

    width: 400
    height: 600

    ListModel { id: chatsModel }

    StatusChatList {
        id: chatList
        anchors.fill: parent
        model: chatsModel
    }

    TestCase {
        name: "ChatListVirtualization"
        when: windowShown

        function test_boundedHeightVirtualizes() {
            for (let i = 0; i < 500; ++i) {
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
                    colorId: i % 10,
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
            wait(500)

            const lv = chatList.statusChatListItems
            compare(lv.count, 500)
            const created = lv.contentItem.children.length
            console.info("created delegates:", created, "of", lv.count,
                         "| listview height:", lv.height, "contentHeight:", lv.contentHeight)
            verify(created < 60, "expected virtualization, got " + created + " delegates")
        }
    }
}
