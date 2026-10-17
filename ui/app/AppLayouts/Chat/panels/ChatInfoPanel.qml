import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils
import StatusQ.Controls

import shared
import shared.controls
import AppLayouts.Chat.controls

ColumnLayout {
    id: root

    enum Tab { Default = -1, Members, Threads, Pins }

    property string chatKey
    property bool membersAvailable: true
    property bool threadsEnabled: true
    property var threadsModel
    property bool threadsLoading
    property bool threadsError
    property Component membersContent
    property Component pinsContent
    // The caller owns selection; the panel derives an available tab.
    property int requestedTab: ChatInfoPanel.Default
    readonly property int currentTab: {
        if (requestedTab === ChatInfoPanel.Members && membersAvailable
                || requestedTab === ChatInfoPanel.Threads && threadsEnabled
                || requestedTab === ChatInfoPanel.Pins)
            return requestedTab
        return d.defaultTab
    }
    readonly property string searchText: searchField.text
    property bool headerInToolbar: false
    readonly property Item headerContent: MembersPanelHeader {
        id: header
        Layout.fillWidth: true
        Layout.margins: root.headerInToolbar ? 0 : Theme.padding
        label: root.currentTab === ChatInfoPanel.Members ? qsTr("Members") :
               root.currentTab === ChatInfoPanel.Threads ? qsTr("Threads") : qsTr("Pins")
        onSearchCheckedChanged: {
            if (!searchChecked)
                searchField.clear()
        }
    }

    signal tabRequested(int tab)
    signal loadThreadsRequested()
    signal openThreadRequested(string threadId)

    spacing: 0

    function reset() {
        header.searchChecked = false
        searchField.clear()
        tabRequested(ChatInfoPanel.Default)
    }

    QtObject {
        id: d
        property bool initialized: false
        readonly property int defaultTab: root.membersAvailable ? ChatInfoPanel.Members :
                                          root.threadsEnabled ? ChatInfoPanel.Threads : ChatInfoPanel.Pins

        function loadThreadsIfSelected() {
            if (root.currentTab === ChatInfoPanel.Threads)
                root.loadThreadsRequested()
        }
    }

    onChatKeyChanged: {
        if (d.initialized) {
            reset()
            Qt.callLater(d.loadThreadsIfSelected)
        }
    }
    onCurrentTabChanged: {
        header.searchChecked = false
        searchField.clear()
        if (d.initialized)
            Qt.callLater(d.loadThreadsIfSelected)
    }
    Component.onCompleted: {
        d.initialized = true
        Qt.callLater(d.loadThreadsIfSelected)
    }

    LayoutItemProxy {
        target: root.headerContent
        visible: !root.headerInToolbar
    }

    SearchBox {
        id: searchField
        objectName: "chatInfoSearchBox"
        Layout.fillWidth: true
        Layout.leftMargin: Theme.padding
        Layout.rightMargin: Theme.padding
        Layout.bottomMargin: visible ? Theme.halfPadding : 0
        visible: header.searchChecked
        placeholderText: root.currentTab === ChatInfoPanel.Members ? qsTr("Search members...") :
                         root.currentTab === ChatInfoPanel.Threads ? qsTr("Search threads...") : qsTr("Search pinned messages...")
        Keys.onEscapePressed: header.searchChecked = false
        onVisibleChanged: {
            if (visible)
                forceActiveFocus()
        }
    }

    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: root.currentTab === ChatInfoPanel.Members
        visible: active
        sourceComponent: root.membersContent
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.currentTab === ChatInfoPanel.Threads

        StatusListView {
            id: threadsList
            objectName: "chatInfoThreadsList"
            visible: !root.threadsLoading && !root.threadsError
            anchors.fill: parent
            anchors.leftMargin: Theme.padding
            anchors.topMargin: Theme.halfPadding
            anchors.bottomMargin: Theme.halfPadding
            spacing: Theme.halfPadding
            model: SortFilterProxyModel {
                sourceModel: root.threadsModel
                filters: SQUtils.SearchFilter {
                    roleName: "title"
                    searchPhrase: root.searchText
                }
                sorters: [
                    RoleSorter { roleName: "lastMessageTimestamp"; sortOrder: Qt.DescendingOrder },
                    StringSorter { roleName: "key"; sortOrder: Qt.DescendingOrder }
                ]
            }
            delegate: ThreadCard {
                // Keep equal panel margins, with the scrollbar in the right gutter.
                width: Math.max(0, threadsList.width - Theme.padding)
                threadId: model.key
                originalMessageId: model.originalMessageId
                title: model.title
                messagesCount: model.messagesCount
                notificationCount: model.notificationCount
                participantsCount: model.participantsCount
                participantsPreviewModel: model.participantsModel
                lastMessage: ({
                    sender: {
                        name: model.lastMessageSenderName,
                        image: model.lastMessageSenderImage,
                        colorId: model.lastMessageSenderColorId
                    },
                    text: model.lastMessageText,
                    timestamp: model.lastMessageTimestamp
                })
                onClicked: (threadId, originalMessageId) => root.openThreadRequested(threadId)
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 2 * Theme.padding
            StatusBaseText {
                Layout.fillWidth: true
                visible: root.threadsLoading || root.threadsError || threadsList.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Theme.palette.secondaryText
                objectName: "chatInfoThreadsState"
                text: root.threadsLoading ? qsTr("Loading threads...") :
                      root.threadsError ? qsTr("Couldn't load threads") :
                      root.searchText ? qsTr("No threads found") : qsTr("Threads will appear here.")
            }
            StatusFlatButton {
                Layout.alignment: Qt.AlignHCenter
                visible: root.threadsError && !root.threadsLoading
                objectName: "chatInfoThreadsRetry"
                text: qsTr("Retry")
                onClicked: root.loadThreadsRequested()
            }
        }
    }

    Loader {
        Layout.fillWidth: true
        Layout.fillHeight: true
        active: root.currentTab === ChatInfoPanel.Pins
        visible: active
        sourceComponent: root.pinsContent
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.palette.separator
    }

    StatusSwitchTabBar {
        id: tabs
        objectName: "chatInfoTabs"
        Layout.fillWidth: true
        Layout.margins: Theme.halfPadding
        implicitWidth: 296
        spacing: 0
        contentItem: ListView {
            model: tabs.contentModel
            currentIndex: tabs.currentIndex
            orientation: ListView.Horizontal
            spacing: tabs.spacing
            interactive: false
            highlightFollowsCurrentItem: false
            clip: true
        }
        currentIndex: root.currentTab
        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex !== root.currentTab)
                root.tabRequested(currentIndex)
        }

        InfoTabButton {
            objectName: "chatInfoMembersTab"
            visible: root.membersAvailable
            icon.name: "members"
            tooltip.text: qsTr("Members")
        }
        InfoTabButton {
            objectName: "chatInfoThreadsTab"
            visible: root.threadsEnabled
            icon.name: "thread"
            tooltip.text: qsTr("Threads")
        }
        InfoTabButton {
            objectName: "chatInfoPinsTab"
            icon.name: "pin"
            tooltip.text: qsTr("Pins")
        }
    }

    component InfoTabButton: StatusSwitchTabButton {
        id: tabButton
        width: visible ? tabs.availableWidth / (1 + Number(root.membersAvailable) + Number(root.threadsEnabled)) : 0
        contentItem: Item {
            implicitWidth: 24
            implicitHeight: 24
            StatusIcon {
                anchors.centerIn: parent
                width: 24
                height: 24
                icon: tabButton.icon.name
                color: tabButton.checked ? Theme.palette.statusSwitchTab.selectedTextColor : Theme.palette.statusSwitchTab.textColor
            }
        }
        StatusToolTip {
            id: tooltip
            visible: tabButton.hovered
        }
        property alias tooltip: tooltip
    }
}
