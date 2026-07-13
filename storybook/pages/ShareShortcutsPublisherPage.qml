import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import mainui
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
            },
            {
                chatId: "chat-bob",
                name: "Bob",
                color: "#4360df",
                colorId: 5,
                icon: "",
                emoji: "",
                sectionId: "personal-section",
                sectionName: "Chat",
                lastMessageTimestamp: 300,
                canPost: true
            },
            {
                chatId: "chat-carol",
                name: "Carol",
                color: "#d37ef4",
                colorId: 6,
                icon: "",
                emoji: "",
                sectionId: "personal-section",
                sectionName: "Chat",
                lastMessageTimestamp: 200,
                canPost: true
            }
        ]

        Component.onCompleted: append(data)
    }

    RecentPostableDestinationsAdaptor {
        id: adaptor
        sourceModel: destinationsModel
    }

    ShareShortcutsPublisher {
        id: publisher

        property int publishCount: 0
        property string lastPayload: "(nothing published yet)"

        model: adaptor.model
        onPublishRequested: (shortcutsJson) => {
            publishCount++
            lastPayload = JSON.stringify(JSON.parse(shortcutsJson), null, 2)
        }
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        ColumnLayout {
            anchors.fill: parent

            Label {
                text: "publishRequested fired %1 time(s); last payload:".arg(publisher.publishCount)
            }

            Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignTop
                wrapMode: Text.Wrap
                font.family: "monospace"
                text: publisher.lastPayload
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
                text: "The publisher watches the top %1 postable destinations "
                      .arg(publisher.maxShortcuts)
                      + "and emits a new payload only when the published set "
                      + "would change (bump recency to reorder). On Android the "
                      + "payload feeds SystemUtils.publishShareShortcuts."
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
