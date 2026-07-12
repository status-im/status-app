import QtQuick
import QtQuick.Controls

import Storybook

import mainui
import mainui.adaptors

SplitView {
    id: root

    Logs { id: logs }

    ListModel {
        id: destinationsModel

        readonly property var data: [
            {
                chatId: "chat-alice",
                name: "Alice",
                color: "#ff7d46",
                colorId: 1,
                icon: "",
                emoji: "",
                sectionId: "personal-section",
                sectionName: "Chat",
                lastMessageTimestamp: 400,
                canPost: true
            },
            {
                chatId: "chat-design-group",
                name: "Design crew",
                color: "#7cda00",
                colorId: 2,
                icon: "",
                emoji: "🎨",
                sectionId: "personal-section",
                sectionName: "Chat",
                lastMessageTimestamp: 900,
                canPost: true
            },
            {
                chatId: "channel-announcements",
                name: "announcements",
                color: "#887af9",
                colorId: 3,
                icon: "",
                emoji: "",
                sectionId: "community-1",
                sectionName: "CryptoKitties",
                lastMessageTimestamp: 1000,
                canPost: false
            },
            {
                chatId: "channel-general",
                name: "general",
                color: "#887af9",
                colorId: 4,
                icon: "",
                emoji: "",
                sectionId: "community-1",
                sectionName: "CryptoKitties",
                lastMessageTimestamp: 700,
                canPost: true
            }
        ]

        Component.onCompleted: append(data)
    }

    RecentPostableDestinationsAdaptor {
        id: adaptor
        sourceModel: destinationsModel
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        ShareDestinationPickerPanel {
            anchors.centerIn: parent
            width: 400
            height: 500

            model: adaptor.model

            onDestinationPicked: (sectionId, chatId, name) => {
                logs.logEvent("ShareDestinationPickerPanel::destinationPicked: "
                              + sectionId + " / " + chatId + " / " + name)
            }
            onCancelRequested: logs.logEvent("ShareDestinationPickerPanel::cancelRequested")
        }
    }

    LogsAndControlsPanel {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 320

        logsView.logText: logs.logText
    }
}
