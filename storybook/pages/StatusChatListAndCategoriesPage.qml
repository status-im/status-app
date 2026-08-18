import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components

import Storybook

import utils

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        StatusChatListAndCategories {
            anchors.centerIn: parent
            width: ctrlWidth.value
            // the list owns its viewport — the host must bound its height
            height: parent.height

            draggableItems: ctrlDraggable.checked
            draggableCategories: ctrlDraggable.checked
            showCategoryActionButtons: true

            Tracer {}

            model: ListModel {
                ListElement {
                    itemId: "id0"
                    categoryId: "id0"
                    active: false
                    notificationsCount: 0
                    hasUnreadMessages: false
                    name: "Category X"
                    icon: ""
                    isCategory: true
                    categoryOpened: true
                    muted: false
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
                    isCategory: false
                    categoryOpened: true
                    hidden: false
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
                    categoryOpened: false
                    muted: false
                    hidden: false
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
                    isCategory: false
                    categoryOpened: true
                    hidden: false
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
                    isCategory: false
                    categoryOpened: true
                    hidden: false
                }
                ListElement {
                    itemId: "id5"
                    categoryId: "id2"
                    name: "Channel Y_3"
                    active: false
                    notificationsCount: 1
                    hasUnreadMessages: false
                    color: ""
                    colorId: 4
                    icon: ""
                    muted: false
                    isCategory: false
                    categoryOpened: true
                    hidden: false
                }
            }

            onChatItemSelected: (categoryId, id) => logs.logEvent("onChatItemSelected", ["categoryId", "id"], arguments)
            onChatItemUnmuted: (id) => logs.logEvent("onChatItemUnmuted", ["id"], arguments)
            onChatItemReordered: (categoryId, chatId, to) => logs.logEvent("onChatItemReordered", ["categoryId", "chatId", "to"], arguments)
            onChatListCategoryReordered: (categoryId, to) => logs.logEvent("onChatListCategoryReordered", ["categoryId", "to"], arguments)
            onCategoryAddButtonClicked: (id) => logs.logEvent("onCategoryAddButtonClicked", ["id"], arguments)
            onToggleCollapsedCommunityCategory: (categoryId, collapsed) => logs.logEvent("onToggleCollapsedCommunityCategory", ["categoryId", "collapsed"], arguments)
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
                    value: 200 // smaller than the default 288
                    ToolTip.text: ctrlWidth.value
                    ToolTip.visible: ctrlWidth.pressed
                }
            }
            Switch {
                id: ctrlDraggable
                text: "Draggable items"
                checked: true
            }
        }
    }
}

// category: Components
// status: good
// https://www.figma.com/design/Mr3rqxxgKJ2zMQ06UAKiWL/Chat%E2%8E%9CDesktop?node-id=10500-370167&m=dev
// https://www.figma.com/design/Mr3rqxxgKJ2zMQ06UAKiWL/Chat%E2%8E%9CDesktop?node-id=5203-44148&m=dev
// https://www.figma.com/design/Mr3rqxxgKJ2zMQ06UAKiWL/Chat%E2%8E%9CDesktop?node-id=5204-38831&m=dev
