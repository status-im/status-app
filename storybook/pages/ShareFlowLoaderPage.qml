import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import utils

import AppLayouts.stores as AppStores
import AppLayouts.Chat.stores as ChatStores

import mainui.sectionLoaders

SplitView {
    id: root

    Logs { id: logs }

    readonly property var sampleImages: [
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC",
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNg+M8AAAICAQB7CYF4AAAAAElFTkSuQmCC",
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYPgPAAEDAQAIicLsAAAAAElFTkSuQmCC"
    ]

    ListModel {
        id: destinationsModel

        readonly property var data: [
            { chatId: "0x04me", name: "Me", color: "", colorId: 0, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.oneToOne, membersCount: 0, onlineStatus: 1, canPost: true, lastMessageTimestamp: 2000, lastOwnMessageTimestamp: 2000 },
            { chatId: "0x04d1", name: "Darrell Steward", color: "", colorId: 3, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.oneToOne, membersCount: 0, onlineStatus: 1, canPost: true, lastMessageTimestamp: 1000, lastOwnMessageTimestamp: 1000 },
            { chatId: "0x04e2", name: "Eleanor Pena", color: "", colorId: 5, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.oneToOne, membersCount: 0, onlineStatus: 1, canPost: true, lastMessageTimestamp: 900, lastOwnMessageTimestamp: 900 },
            { chatId: "channel-memes", name: "memes", color: "#887af9", colorId: 4, icon: "", emoji: "😎", sectionId: "community-status", sectionName: "Status", chatType: Constants.chatType.communityChat, membersCount: 0, onlineStatus: 0, canPost: true, lastMessageTimestamp: 700, lastOwnMessageTimestamp: 700 },
            { chatId: "channel-announcements", name: "announcements", color: "#887af9", colorId: 4, icon: "", emoji: "📣", sectionId: "community-status", sectionName: "Status", chatType: Constants.chatType.communityChat, membersCount: 0, onlineStatus: 0, canPost: false, lastMessageTimestamp: 650, lastOwnMessageTimestamp: 0 },
            { chatId: "group-status-team", name: "Status App Team", color: "#7140fd", colorId: 0, icon: "", emoji: "", sectionId: "personal", sectionName: "Chat", chatType: Constants.chatType.privateGroupChat, membersCount: 25, onlineStatus: 0, canPost: true, lastMessageTimestamp: 200, lastOwnMessageTimestamp: 200 }
        ]

        Component.onCompleted: append(data)
    }

    AppStores.RootStore {
        id: rootStore

        readonly property bool sectionsLoaded: ctrlSectionsLoaded.checked
        readonly property var chatSearchModel: destinationsModel

        function releaseShareIntakeFiles(imagePaths) {
            logs.logEvent("releaseShareIntakeFiles: " + imagePaths.length + " image(s)")
        }
        function setActiveSectionChat(sectionId, chatId) {
            logs.logEvent("setActiveSectionChat: " + sectionId + " / " + chatId)
        }
    }

    ChatStores.RootStore {
        id: rootChatStore

        function sendSharedContent(destinations, text, imagePaths) {
            logs.logEvent("sendSharedContent: " + JSON.stringify(destinations) + " / " + text
                          + " / " + imagePaths.length + " image(s) -> " + ctrlSendSucceeds.checked)
            return ctrlSendSucceeds.checked
        }
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        ShareFlowLoader {
            id: shareFlowLoader

            rootStore: rootStore
            rootChatStore: rootChatStore
            excludedChatId: "0x04me"
            unlimitedImages: ctrlUnlimitedImages.checked
        }

        Label {
            anchors.centerIn: parent
            text: shareFlowLoader.active ? "share flow open" : "share flow idle"
        }
    }

    LogsAndControlsPanel {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 320

        logsView.logText: logs.logText

        ColumnLayout {
            TextField { id: ctrlText; Layout.fillWidth: true; text: "https://youtu.be/d3wHC956WLk" }
            RowLayout {
                Label { text: "images" }
                SpinBox { id: ctrlImages; from: 0; to: 3 }
            }
            CheckBox { id: ctrlSectionsLoaded; text: "sections loaded"; checked: true }
            CheckBox { id: ctrlUnlimitedImages; text: "unlimited images"; checked: true }
            CheckBox { id: ctrlSendSucceeds; text: "send succeeds"; checked: true }
            Button {
                text: "Launch share flow"
                onClicked: shareFlowLoader.launch(ctrlText.text, root.sampleImages.slice(0, ctrlImages.value))
            }
        }
    }
}

// category: Popups
