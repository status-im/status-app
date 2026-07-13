import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core

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
            }
        ]

        Component.onCompleted: append(data)
    }

    RecentPostableDestinationsAdaptor {
        id: adaptor
        sourceModel: destinationsModel
    }

    SendMessageIntentDonor {
        id: donor

        property int donationCount: 0
        property string lastDonation: "(nothing donated yet)"

        model: adaptor.model
        onDonationRequested: (conversationId, name, iconPath) => {
            donationCount++
            lastDonation = JSON.stringify({ conversationId, name, iconPath }, null, 2)
        }
    }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        ColumnLayout {
            anchors.fill: parent

            Label {
                text: "donationRequested fired %1 time(s); last donation:".arg(donor.donationCount)
            }

            Label {
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignTop
                wrapMode: Text.Wrap
                font.family: "monospace"
                text: donor.lastDonation
            }

            Image {
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                source: {
                    try {
                        const iconPath = JSON.parse(donor.lastDonation).iconPath
                        return iconPath ? "file://" + iconPath : ""
                    } catch (e) {
                        return ""
                    }
                }
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
                text: "\"Send\" simulates a successful send to that chat: the "
                      + "donor looks the destination up in the recent postable "
                      + "destinations model, renders its avatar and emits a "
                      + "donation. On iOS the donation feeds "
                      + "MobileUI.donateSendMessageInteraction, powering the "
                      + "share-sheet suggestion chips. A non-postable "
                      + "destination (announcements) is never donated."
            }

            CheckBox {
                id: renderIconsCheckBox
                text: "render avatars (iconDirectory set)"
                checked: false
                onToggled: donor.iconDirectory = checked
                           ? SystemUtils.shareShortcutsIconDirectory() : ""
            }

            Repeater {
                model: destinationsModel

                Button {
                    text: "Send to %1".arg(model.name)
                    onClicked: donor.donateForChat(model.chatId)
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
