import QtQuick
import QtTest

import AppLayouts.Chat.views
import AppLayouts.Chat.stores as ChatStores

// Bisect: does the real ContactsColumnView keep the chat list virtualized
// when bounded, or does its internal structure expand the list?
Item {
    id: root

    width: 400
    height: 600

    ListModel { id: chatsModel }

    QtObject {
        id: sectionModuleMock

        property var model: chatsModel
        property var activeItem: ({ id: "chat-0" })

        function isCommunity() { return false }
        function setActiveItem(id) {}
        function getItemAsJson(id) { return "{}" }
        function muteChat(chatId, interval) {}
        function unmuteChat(chatId) {}
        function markAllMessagesRead(chatId) {}
        function clearChatHistory(chatId) {}
        function leaveChat(chatId) {}
        function updateGroupChatDetails() {}
    }

    ChatStores.RootStore { id: storeMock }

    ContactsColumnView {
        id: view
        anchors.fill: parent
        chatSectionModule: sectionModuleMock
        store: storeMock
    }

    TestCase {
        name: "ContactsColumnVirtualization"
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
                    categoryPosition: -1,
                    lastMessageTimestamp: 1000000 - i
                })
            }
            wait(500)

            const chatList = findChild(view, "ContactsColumnView_chatList")
            verify(!!chatList)
            const lv = chatList.statusChatListItems
            compare(lv.count, 500)
            const created = lv.contentItem.children.length
            console.info("created delegates:", created, "of", lv.count,
                         "| chatList height:", chatList.height, "lv height:", lv.height,
                         "contentHeight:", lv.contentHeight)
            verify(created < 60, "expected virtualization, got " + created + " delegates")
        }
    }
}
