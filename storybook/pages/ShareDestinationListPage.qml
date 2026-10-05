import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import StatusQ.Core.Theme

import utils
import mainui

SplitView {
    id: root

    Logs { id: logs }

    ListModel {
        id: destinationsModel

        readonly property var data: [
            { chatId: "0x04d1", name: "Darrell Steward", color: "", colorId: 3, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.oneToOne, membersCount: 0, onlineStatus: 1 },
            { chatId: "0x04e2", name: "Eleanor Pena", color: "", colorId: 5, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.oneToOne, membersCount: 0, onlineStatus: 1 },
            { chatId: "channel-feedback-mobile", name: "feedback-mobile", color: "#887af9", colorId: 4, icon: "", emoji: "📱", sectionId: "community-status", sectionName: "Status", chatType: Constants.chatType.communityChat, membersCount: 0, onlineStatus: 0 },
            { chatId: "channel-memes", name: "memes", color: "#887af9", colorId: 4, icon: "", emoji: "😎", sectionId: "community-status", sectionName: "Status", chatType: Constants.chatType.communityChat, membersCount: 0, onlineStatus: 0 },
            { chatId: "channel-pets", name: "pets", color: "#887af9", colorId: 4, icon: "", emoji: "🐶", sectionId: "community-status", sectionName: "Status", chatType: Constants.chatType.communityChat, membersCount: 0, onlineStatus: 0 },
            { chatId: "channel-feedback-desktop", name: "feedback-desktop", color: "#ff7d46", colorId: 1, icon: "", emoji: "🖥️", sectionId: "community-status", sectionName: "Status", chatType: Constants.chatType.communityChat, membersCount: 0, onlineStatus: 0 },
            { chatId: "0x04j3", name: "Jacob Jones", color: "", colorId: 2, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.oneToOne, membersCount: 0, onlineStatus: 1 },
            { chatId: "0x04b4", name: "Bessie Cooper", color: "", colorId: 6, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.oneToOne, membersCount: 0, onlineStatus: 1 },
            { chatId: "group-status-team", name: "Status App Team", color: "#7140fd", colorId: 0, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.privateGroupChat, membersCount: 25, onlineStatus: 0 },
            { chatId: "group-travel", name: "Travel Days", color: "#23ada0", colorId: 0, icon: "", emoji: "🏔️", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.privateGroupChat, membersCount: 5, onlineStatus: 0 }
        ]

        Component.onCompleted: append(data)
    }

    ShareSelection { id: selection }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 800
            color: Theme.palette.statusListItem.backgroundColor
            border.color: Theme.palette.baseColor2

            ShareDestinationList {
                anchors.fill: parent
                model: destinationsModel
                selection: selection
                chatTypeFilter: ctrlType.currentValue
                selectedOnly: ctrlSelectedOnly.checked
                searchPhrase: ctrlSearch.text
                onToggleRequested: chatId => {
                    selection.toggle(chatId)
                    logs.logEvent("toggleRequested: " + chatId)
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 320

        logsView.logText: logs.logText

        ColumnLayout {
            ComboBox {
                id: ctrlType
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: "All", value: -1 },
                    { text: "Contacts", value: Constants.chatType.oneToOne },
                    { text: "Groups", value: Constants.chatType.privateGroupChat },
                    { text: "Communities", value: Constants.chatType.communityChat }
                ]
            }
            CheckBox { id: ctrlSelectedOnly; text: "selected only" }
            TextField { id: ctrlSearch; placeholderText: "search" }
            Button { text: "clear selection"; onClicked: selection.clear() }
        }
    }
}

// category: Panels
