import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import StatusQ.Core.Theme

import utils
import mainui
import mainui.adaptors

SplitView {
    id: root

    Logs { id: logs }

    ListModel {
        id: destinationsModel

        readonly property var data: [
            { chatId: "0x04d1", name: "Darrell Steward", color: "", colorId: 3, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.oneToOne, membersCount: 0, onlineStatus: 1, canPost: true, lastMessageTimestamp: 1000, lastOwnMessageTimestamp: 1000 },
            { chatId: "0x04e2", name: "Eleanor Pena", color: "", colorId: 5, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.oneToOne, membersCount: 0, onlineStatus: 1, canPost: true, lastMessageTimestamp: 900, lastOwnMessageTimestamp: 900 },
            { chatId: "channel-feedback-mobile", name: "feedback-mobile", color: "#887af9", colorId: 4, icon: "", emoji: "📱", sectionId: "community-status", sectionName: "Status", chatType: Constants.chatType.communityChat, membersCount: 0, onlineStatus: 0, canPost: true, lastMessageTimestamp: 800, lastOwnMessageTimestamp: 800 },
            { chatId: "channel-memes", name: "memes", color: "#887af9", colorId: 4, icon: "", emoji: "😎", sectionId: "community-status", sectionName: "Status", chatType: Constants.chatType.communityChat, membersCount: 0, onlineStatus: 0, canPost: true, lastMessageTimestamp: 700, lastOwnMessageTimestamp: 700 },
            { chatId: "channel-pets", name: "pets", color: "#887af9", colorId: 4, icon: "", emoji: "🐶", sectionId: "community-status", sectionName: "Status", chatType: Constants.chatType.communityChat, membersCount: 0, onlineStatus: 0, canPost: true, lastMessageTimestamp: 600, lastOwnMessageTimestamp: 600 },
            { chatId: "channel-feedback-desktop", name: "feedback-desktop", color: "#ff7d46", colorId: 1, icon: "", emoji: "🖥️", sectionId: "community-status", sectionName: "Status", chatType: Constants.chatType.communityChat, membersCount: 0, onlineStatus: 0, canPost: true, lastMessageTimestamp: 500, lastOwnMessageTimestamp: 500 },
            { chatId: "0x04j3", name: "Jacob Jones", color: "", colorId: 2, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.oneToOne, membersCount: 0, onlineStatus: 1, canPost: true, lastMessageTimestamp: 400, lastOwnMessageTimestamp: 400 },
            { chatId: "0x04b4", name: "Bessie Cooper", color: "", colorId: 6, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.oneToOne, membersCount: 0, onlineStatus: 1, canPost: true, lastMessageTimestamp: 300, lastOwnMessageTimestamp: 300 },
            { chatId: "group-status-team", name: "Status App Team", color: "#7140fd", colorId: 0, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.privateGroupChat, membersCount: 25, onlineStatus: 0, canPost: true, lastMessageTimestamp: 200, lastOwnMessageTimestamp: 200 },
            { chatId: "group-travel", name: "Travel Days", color: "#23ada0", colorId: 0, icon: "", emoji: "🏔️", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.privateGroupChat, membersCount: 5, onlineStatus: 0, canPost: true, lastMessageTimestamp: 100, lastOwnMessageTimestamp: 100 }
        ]

        Component.onCompleted: append(data)
    }

    RecentPostableDestinationsAdaptor {
        id: adaptor
        sourceModel: destinationsModel
    }

    QtObject {
        id: states

        readonly property var names: [
            "Default (All, 0 selected)", "All, 1 selected", "All, 2 selected",
            "Selected mode, 2 selected",
            "Contacts", "Groups", "Communities", "Search 'fee'"
        ]

        function currentListItem() {
            const tabs = findChildByObjectName(panel, "shareDestinationPickerTabs")
            return tabs.itemAt(tabs.currentIndex).item
        }

        function tick(chatId) {
            const delegate = findChildByObjectName(currentListItem(), "shareDestinationDelegate_" + chatId)
            if (delegate)
                delegate.toggled(chatId)
        }

        function findChildByObjectName(item, name) {
            if (item.objectName === name)
                return item
            for (let i = 0; i < item.children.length; i++) {
                const found = findChildByObjectName(item.children[i], name)
                if (found)
                    return found
            }
            return null
        }

        function apply(index) {
            panel.reset()
            const tabBar = findChildByObjectName(panel, "shareDestinationPickerTabBar")
            switch (index) {
            case 1: tick("0x04j3"); break
            case 2: tick("0x04j3"); tick("channel-pets"); break
            case 3:
                tick("0x04j3")
                tick("channel-pets")
                findChildByObjectName(panel, "shareDestinationPickerSelectedToggle").clicked()
                break
            case 4: tabBar.currentIndex = ShareDestinationTabBar.Tab.Contacts; break
            case 5: tabBar.currentIndex = ShareDestinationTabBar.Tab.Groups; break
            case 6: tabBar.currentIndex = ShareDestinationTabBar.Tab.Communities; break
            case 7:
                findChildByObjectName(panel, "shareDestinationPickerSearchToggle").clicked(null)
                findChildByObjectName(panel, "shareDestinationPickerSearchBox").text = "fee"
                break
            }
        }
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 800
            color: Theme.palette.statusListItem.backgroundColor
            border.color: Theme.palette.baseColor2

            ShareDestinationPickerPanel {
                id: panel
                anchors.fill: parent
                model: adaptor.model
                text: "https://youtu.be/d3wHC956WLk"
                onSendRequested: (destinations, text, imagePaths) =>
                    logs.logEvent("sendRequested: " + JSON.stringify(destinations) + " / " + text
                                  + " / " + imagePaths.length + " image(s)")
                onCancelRequested: logs.logEvent("cancelRequested")
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 320

        logsView.logText: logs.logText

        ColumnLayout {
            Label { text: "Figma state" }
            ComboBox {
                Layout.fillWidth: true
                model: states.names
                onActivated: index => states.apply(index)
            }
            Label { text: "selected: " + panel.selectedCount }
        }
    }
}

// category: Panels
