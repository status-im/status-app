import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import mainui.adaptors

SplitView {
    id: root

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

        ListView {
            anchors.fill: parent
            model: adaptor.model
            spacing: 4

            delegate: Label {
                text: "%1 (%2) — lastMessageTimestamp: %3".arg(model.name)
                        .arg(model.sectionName).arg(model.lastMessageTimestamp)
            }
        }
    }

    Pane {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 350

        ColumnLayout {
            anchors.fill: parent

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Source rows (toggle post rights, bump recency); the left "
                      + "pane shows the adaptor output: postable only, most "
                      + "recent first."
            }

            Repeater {
                model: destinationsModel

                RowLayout {
                    Layout.fillWidth: true

                    CheckBox {
                        text: "%1 canPost".arg(model.name)
                        checked: model.canPost
                        onToggled: destinationsModel.setProperty(index, "canPost", checked)
                    }

                    Button {
                        text: "Bump"
                        onClicked: destinationsModel.setProperty(index, "lastMessageTimestamp",
                                                                 model.lastMessageTimestamp + 1000)
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
