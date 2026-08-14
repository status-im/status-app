import QtQuick
import QtTest

import StatusQ.Components

// Guard (stack PR #21943): chats hidden by a collapsed category must be
// filtered out of the view via the model-computed "hidden" role — a
// zero-height delegate would still be instantiated by the ListView (with
// spacing 0 a zero-height item never advances the fill cursor, so one pass
// would synchronously instantiate every hidden row of the category).
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
        name: "CollapsedCategoryVirtualization"
        when: windowShown

        function test_collapsedCategoryStaysVirtualized() {
            chatsModel.append({
                itemId: "cat-0",
                categoryId: "cat-0",
                name: "Collapsed category",
                type: 0,
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
                categoryOpened: false,
                hidden: false,
                usesDefaultName: false,
                onlineStatus: 1,
                requiresPermissions: false,
                locked: false,
                isCategory: true,
                position: 0,
                categoryPosition: 0,
                lastMessageTimestamp: 0
            })

            // 500 channels of that category: not active, not unread, not
            // mentioned — the backend computes hidden == true for every one
            for (let i = 0; i < 500; ++i) {
                chatsModel.append({
                    itemId: "chat-" + i,
                    categoryId: "cat-0",
                    name: "Channel " + i,
                    type: 1,
                    muted: false,
                    active: false,
                    blocked: false,
                    hasUnreadMessages: false,
                    notificationsCount: 0,
                    highlight: false,
                    icon: "",
                    emoji: "",
                    color: "",
                    colorId: i % 10,
                    categoryOpened: false,
                    hidden: true,
                    usesDefaultName: false,
                    onlineStatus: 1,
                    requiresPermissions: false,
                    locked: false,
                    isCategory: false,
                    position: i,
                    categoryPosition: 0,
                    lastMessageTimestamp: 1000000 - i
                })
            }

            // hidden rows are filtered out of the view model entirely
            const lv = chatList.statusChatListItems
            tryCompare(lv, "count", 1)
            waitForRendering(lv)

            // geometry contract: the collapsed category is the only visible row
            compare(lv.contentHeight, chatList.categoryRowHeight)

            const created = lv.contentItem.children.length
            verify(created < 60,
                   "expected the hidden rows to stay virtualized, got "
                   + created + " instantiated delegates")
        }
    }
}
