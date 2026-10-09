import QtQuick
import QtQuick.Controls

import AppLayouts.Chat.controls
import Storybook

import StatusQ.Core.Theme

SplitView {
    id: root

    Logs { id: logs }

    readonly property bool deletedState: stateCombo.currentText === "deleted"
    readonly property var participants: [
        { id: "you", name: "You", colorId: 0 },
        { id: "volo", name: "Volo", colorId: 1 },
        { id: "alisher", name: "Alisher", image: "https://i.pravatar.cc/128?img=32", colorId: 2 },
        { id: "tina", name: "Tina", colorId: 3 },
        { id: "ship", name: "Captain", image: "https://i.pravatar.cc/128?img=12", colorId: 4 },
        { id: "marcus", name: "Marcus", colorId: 5 },
        { id: "sara", name: "Sara", colorId: 6 },
        { id: "nina", name: "Nina", colorId: 7 },
        { id: "kai", name: "Kai", colorId: 8 },
        { id: "leo", name: "Leo", image: "https://i.pravatar.cc/128?img=15", colorId: 9 },
        { id: "maya", name: "Maya", colorId: 10 },
        { id: "omar", name: "Omar", colorId: 11 },
        { id: "ivy", name: "Ivy", image: "https://i.pravatar.cc/128?img=47", colorId: 0 },
        { id: "ren", name: "Ren", colorId: 1 },
        { id: "zoe", name: "Zoe", colorId: 2 }
    ]

    ListModel {
        id: participantsListModel

        Component.onCompleted: {
            for (let i = 0; i < root.participants.length; ++i) {
                const participant = root.participants[i]
                append({
                    id: participant.id,
                    name: participant.name,
                    image: participant.image || "",
                    colorId: participant.colorId
                })
            }
        }
    }
    property int previewWidth: 402

    orientation: Qt.Horizontal

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.fill: parent
            color: Theme.palette.baseColor4
        }

        ThreadCard {
            id: threadCard

            width: Math.max(296, Math.min(parent.width - 80, root.previewWidth))
            height: implicitHeight
            anchors.centerIn: parent
            threadId: "t-m1"
            originalMessageId: "m1"
            threadState: root.deletedState ? ThreadCard.State.Deleted : ThreadCard.State.Active
            title: titleField.text
            messagesCount: messagesCount.value
            notificationCount: notificationCount.value
            participantsPreviewModel: participantsListModel
            participantsCount: participantsCount.value
            lastMessage: ({
                sender: { name: "You", color: "#4360DF" },
                text: lastMessageField.text,
                timestamp: Date.now() - timeField.value * 60 * 1000
            })
            deletedMessage: ({
                sender: { name: deletedByNameField.text, color: "#26A69A" },
                timestamp: Date.now() - deletedAtField.value * 60 * 1000
            })
            onClicked: (threadId, originalMessageId) => logs.logEvent("ThreadCard::clicked", ["threadId", "originalMessageId"], [threadId, originalMessageId])
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 320
        SplitView.preferredWidth: 360

        logsView.logText: logs.logText

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 8
            spacing: 8

            Label {
                width: parent.width
                text: "Width"
            }

            Slider {
                width: parent.width
                from: 296
                to: 620
                stepSize: 1
                value: root.previewWidth
                onMoved: root.previewWidth = Math.round(value)
            }

            Label {
                width: parent.width
                text: "State"
                font.bold: true
            }

            ComboBox {
                id: stateCombo
                width: parent.width
                model: ["active", "deleted"]
            }

            Rectangle {
                width: parent.width
                height: activeControls.implicitHeight + 16
                visible: !root.deletedState
                radius: 6
                color: "transparent"
                border.width: 1
                border.color: Theme.palette.border

                Column {
                    id: activeControls

                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Label {
                        width: parent.width
                        text: "Title"
                    }
                    TextField {
                        id: titleField
                        width: parent.width
                        text: "Threads MVP"
                    }

                    Label {
                        width: parent.width
                        text: "Last message"
                    }
                    TextField {
                        id: lastMessageField
                        width: parent.width
                        text: "Sharing the summary back to the channel too."
                    }

                    Label {
                        width: parent.width
                        text: "Last message minutes ago"
                    }
                    SpinBox {
                        id: timeField
                        width: parent.width
                        from: 0
                        to: 999
                        value: 38
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Label {
                            width: parent.width - messagesCount.width - parent.spacing
                            text: "Messages"
                        }
                        SpinBox {
                            id: messagesCount
                            width: 120
                            from: 1
                            to: 999
                            value: 4
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Label {
                            width: parent.width - participantsCount.width - parent.spacing
                            text: "Participants"
                        }
                        SpinBox {
                            id: participantsCount
                            width: 120
                            from: 1
                            to: root.participants.length
                            value: 15
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Label {
                            width: parent.width - notificationCount.width - parent.spacing
                            text: "Badge"
                        }
                        SpinBox {
                            id: notificationCount
                            width: 120
                            from: 0
                            to: 999
                            value: 2
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: deletedControls.implicitHeight + 16
                visible: root.deletedState
                radius: 6
                color: "transparent"
                border.width: 1
                border.color: Theme.palette.border

                Column {
                    id: deletedControls

                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Label {
                        width: parent.width
                        text: "Deleted by"
                    }
                    TextField {
                        id: deletedByNameField
                        width: parent.width
                        text: "Marcus"
                    }

                    Label {
                        width: parent.width
                        text: "Deleted minutes ago"
                    }
                    SpinBox {
                        id: deletedAtField
                        width: parent.width
                        from: 0
                        to: 999
                        value: 5
                    }
                }
            }
        }
    }
}

// category: Chat
// status: good
