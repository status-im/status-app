import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components

import Storybook

import utils

import SortFilterProxyModel

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        contentItem: Item {
            RowLayout {
                spacing: 50
                height: parent.height
                anchors.horizontalCenter: parent.horizontalCenter
                ColumnLayout {
                    Label {
                        text: "Community channels:"
                    }
                    CustomStatusChatListAndCategories {
                        model: SortFilterProxyModel {
                            sourceModel: chatListModel
                            filters: [
                                AnyOf {
                                    ValueFilter {
                                        roleName: "type"
                                        value: StatusChatListItem.Type.CommunityChat
                                    }
                                    ValueFilter {
                                        roleName: "isCategory"
                                        value: true
                                    }
                                }
                            ]
                        }
                    }
                }
                ColumnLayout {
                    Label {
                        text: "Non-community channels:"
                    }
                    CustomStatusChatListAndCategories {
                        model: SortFilterProxyModel {
                            sourceModel: chatListModel
                            filters: [
                                AllOf {
                                    ValueFilter {
                                        roleName: "type"
                                        value: StatusChatListItem.Type.CommunityChat
                                        inverted: true
                                    }
                                    ValueFilter {
                                        roleName: "isCategory"
                                        value: false
                                    }
                                }
                            ]
                        }
                    }
                }
            }
        }
    }

    component CustomStatusChatListAndCategories: StatusChatListAndCategories {
        Layout.preferredWidth: ctrlWidth.value
        Layout.fillHeight: true

        draggableItems: ctrlDraggable.checked
        showCategoryActionButtons: true
        showThreads: ctrlShowThreads.checked
        isMobile: ctrlIsMobile.checked

        // TODO popup menus

        Tracer {}

        onChatItemSelected: function(categoryId, id) {
            logs.logEvent("onChatItemSelected", ["categoryId", "id"], arguments)
            selectItem(categoryId, id)
        }
        onChatItemClicked: function(id) {
            logs.logEvent("onChatItemClicked", ["id"], arguments)
        }
        onChatItemUnmuted: function(id) {
            logs.logEvent("onChatItemUnmuted", ["id"], arguments)
            unmuteItem(id)
        }
        onChatItemReordered: function(categoryId, chatId, to) {
            logs.logEvent("onChatItemReordered", ["categoryId", "chatId", "to"], arguments)
        }
        onChatListCategoryReordered: function(categoryId, to) {
            logs.logEvent("onChatListCategoryReordered", ["categoryId", "to"], arguments)
        }
        onCategoryAddButtonClicked: function(id) {
            logs.logEvent("onCategoryAddButtonClicked", ["id"], arguments)
        }
        onToggleCollapsedCommunityCategory: function(categoryId, collapsed) {
            logs.logEvent("onToggleCollapsedCommunityCategory", ["categoryId", "collapsed"], arguments)
            expandCollapseCategory(categoryId, collapsed)
        }
    }

    function selectItem(categoryId, id) {
        const count = chatListModel.count
        for (let i = 0; i < count; i++) {
            const item = chatListModel.get(i)
            if (!!item && item.itemId === id)
                item.active = true
            else
                item.active = false
        }
    }

    function expandCollapseCategory(categoryId: string, collapse: bool): void {
        const count = chatListModel.count
        for (let i = 0; i < count; i++) {
            const item = chatListModel.get(i)
            if (!!item && item.categoryId === categoryId) {
                if (item.isCategory)
                    item.categoryOpened = !collapse
                else
                    item.hidden = collapse
            }
        }
    }

    function unmuteItem(id) {
        const count = chatListModel.count
        for (let i = 0; i < count; i++) {
            const item = chatListModel.get(i)
            if (!!item && item.itemId === id) {
                item.muted = false
            }
        }
    }

    ListModel {
        id: chatListModel
        ListElement {
            itemId: "id0"
            categoryId: "id0"
            active: false
            notificationsCount: 0
            hasUnreadMessages: false
            name: "Category X"
            icon: ""
            isCategory: true
            categoryOpened: false
            muted: true
            hidden: false
        }
        ListElement {
            itemId: "id1"
            name: "Channel X"
            categoryId: "id0"
            active: false
            notificationsCount: 0
            hasUnreadMessages: false
            color: ""
            colorId: 1
            icon: ""
            muted: false
            hidden: true
            type: StatusChatListItem.Type.CommunityChat
        }
        ListElement {
            itemId: "id2"
            categoryId: "id2"
            name: "Category Y"
            active: false
            notificationsCount: 12
            hasUnreadMessages: false
            color: ""
            colorId: 2
            icon: ""
            isCategory: true
            categoryOpened: true
            muted: false
            hidden: false
            categoryPosition: 0
        }
        ListElement {
            itemId: "id3"
            categoryId: "id2"
            name: "Channel Y_1"
            emoji: "💩"
            active: false
            notificationsCount: 0
            hasUnreadMessages: true
            color: ""
            colorId: 2
            icon: ""
            muted: false
            hidden: false
            requiresPermissions: true
            locked: true
            categoryPosition: 0
            position: 0
            type: StatusChatListItem.Type.CommunityChat
        }
        ListElement {
            itemId: "id4"
            categoryId: "id2"
            name: "Channel Y_2"
            active: false
            notificationsCount: 0
            hasUnreadMessages: false
            color: "red"
            colorId: 3
            icon: ""
            muted: false
            hidden: false
            categoryPosition: 0
            position: 1
            type: StatusChatListItem.Type.CommunityChat
        }
        ListElement {
            itemId: "id5"
            categoryId: "id2"
            name: "Channel Y_3"
            active: false
            notificationsCount: 42
            hasUnreadMessages: false
            color: ""
            colorId: 6
            icon: ""
            muted: false
            hidden: false
            categoryPosition: 0
            position: 2
            type: StatusChatListItem.Type.CommunityChat
        }
        ListElement {
            itemId: "id5#1"
            categoryId: "id2"
            name: "Y_3 thread#1"
            isThread: true
            parentChatId: "id5"
            active: false
            notificationsCount: 0
            hasUnreadMessages: true
            color: ""
            colorId: 6
            icon: ""
            muted: false
            hidden: false
            categoryPosition: 0
            position: 2
            type: StatusChatListItem.Type.CommunityChat
        }
        ListElement {
            itemId: "id5#2"
            categoryId: "id2"
            name: "Y_3 thread#2"
            isThread: true
            parentChatId: "id5"
            active: false
            notificationsCount: 6
            hasUnreadMessages: false
            color: ""
            colorId: 6
            icon: ""
            muted: false
            hidden: false
            categoryPosition: 0
            position: 2
            type: StatusChatListItem.Type.CommunityChat
        }
        ListElement {
            itemId: "id5#3"
            categoryId: "id2"
            name: "Y_3 thread#3"
            isThread: true
            parentChatId: "id5"
            active: false
            notificationsCount: 0
            hasUnreadMessages: false
            color: ""
            colorId: 6
            icon: ""
            muted: false
            hidden: false
            categoryPosition: 0
            position: 2
            type: StatusChatListItem.Type.CommunityChat
        }
        ListElement {
            itemId: "id5#4"
            categoryId: "id2"
            name: "Y_3 thread#4"
            isThread: true
            parentChatId: "id5"
            active: false
            notificationsCount: 0
            hasUnreadMessages: true
            color: ""
            colorId: 6
            icon: ""
            muted: true
            hidden: false
            categoryPosition: 0
            position: 2
            type: StatusChatListItem.Type.CommunityChat
        }
        ListElement {
            itemId: "id6"
            categoryId: "id2"
            name: "Channel Y_4"
            active: false
            notificationsCount: 666
            hasUnreadMessages: true
            color: ""
            colorId: 2
            icon: ""
            muted: true
            hidden: false
            requiresPermissions: true
            locked: false
            categoryPosition: 0
            position: 3
            type: StatusChatListItem.Type.CommunityChat
        }
        // non-community
        ListElement {
            itemId: "id7"
            categoryId: ""
            name: "Jane Doe"
            active: false
            notificationsCount: 0
            hasUnreadMessages: false
            color: ""
            colorId: 9
            icon: "https://i.pravatar.cc/64?u=jane.doe@acme.com"
            muted: false
            hidden: false
            categoryPosition: 0
            position: 3
            type: StatusChatListItem.Type.OneToOneChat
        }
        ListElement {
            itemId: "id8"
            categoryId: ""
            name: "Public chat"
            active: false
            notificationsCount: 0
            hasUnreadMessages: false
            color: ""
            colorId: 8
            icon: ""
            muted: false
            hidden: false
            categoryPosition: 0
            position: 4
            type: StatusChatListItem.Type.PublicChat
        }
        ListElement {
            itemId: "id9"
            categoryId: ""
            name: "Cool group"
            active: false
            notificationsCount: 0
            hasUnreadMessages: false
            color: ""
            colorId: 3
            icon: ""
            muted: false
            hidden: false
            categoryPosition: 0
            position: 5
            type: StatusChatListItem.Type.GroupChat
        }
        ListElement {
            itemId: "id9#1"
            categoryId: ""
            name: "Cool group thread#1"
            isThread: true
            parentChatId: "id9"
            active: true
            notificationsCount: 0
            hasUnreadMessages: false
            color: ""
            colorId: 3
            icon: ""
            muted: false
            hidden: false
            categoryPosition: 0
            position: 5
            type: StatusChatListItem.Type.GroupChat
        }
        ListElement {
            itemId: "id10"
            categoryId: ""
            name: "Mr. Noname"
            active: false
            notificationsCount: 0
            hasUnreadMessages: true
            color: ""
            colorId: 5
            icon: ""
            muted: false
            hidden: false
            categoryPosition: 0
            position: 6
            type: StatusChatListItem.Type.OneToOneChat
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 200
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            RowLayout {
                Label { text: "Width:" }
                Slider {
                    id: ctrlWidth
                    from: 30
                    to: 600
                    stepSize: 10
                    value: Constants.chatSectionLeftColumnWidth * .9 // smaller than the default 288
                    ToolTip.text: ctrlWidth.value
                    ToolTip.visible: ctrlWidth.pressed
                }
            }
            Switch {
                id: ctrlShowThreads
                text: "Show threads"
                checked: true
            }
            Switch {
                id: ctrlDraggable
                text: "Draggable items (drop not supported here)"
                checked: true
            }
            Switch {
                id: ctrlIsMobile
                text: "Is mobile?"
                checked: false
            }
        }
    }
}

// category: Components
// status: good
// https://www.figma.com/design/Mr3rqxxgKJ2zMQ06UAKiWL/Chat%E2%8E%9CDesktop?node-id=10500-370167&m=dev
// https://www.figma.com/design/Mr3rqxxgKJ2zMQ06UAKiWL/Chat%E2%8E%9CDesktop?node-id=5203-44148&m=dev
// https://www.figma.com/design/Mr3rqxxgKJ2zMQ06UAKiWL/Chat%E2%8E%9CDesktop?node-id=5204-38831&m=dev
