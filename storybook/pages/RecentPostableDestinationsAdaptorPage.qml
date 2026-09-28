import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
                lastOwnMessageTimestamp: 400,
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
                lastOwnMessageTimestamp: 100,
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
                lastOwnMessageTimestamp: 0,
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
                lastOwnMessageTimestamp: 0,
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
                text: "%1 (%2) — own: %3, any: %4".arg(model.name)
                        .arg(model.sectionName).arg(model.lastOwnMessageTimestamp)
                        .arg(model.lastMessageTimestamp)
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
                      + "pane shows the adaptor output: postable only, chats "
                      + "the user sent to first (by own-send recency), then "
                      + "never-sent-to ones by any-message recency. 'Send' "
                      + "bumps both recency roles like a real send; 'Receive' "
                      + "bumps only any-message recency and must not promote "
                      + "the row above sent-to chats."
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
                        text: "Send"
                        onClicked: {
                            const bumped = model.lastMessageTimestamp + 1000
                            destinationsModel.setProperty(index, "lastMessageTimestamp", bumped)
                            destinationsModel.setProperty(index, "lastOwnMessageTimestamp", bumped)
                        }
                    }

                    Button {
                        text: "Receive"
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
