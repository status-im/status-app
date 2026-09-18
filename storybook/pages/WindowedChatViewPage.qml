pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import "ChatViewPocComponents"

SplitView {
    id: root

    readonly property int messageCount: 200

    // Sample data /////////////////////////////////////////////////////////////
    //
    // Deterministic on purpose - every reload gives the same heights, so what
    // the view does is comparable between runs.
    //
    // The roles are prefixed because MessageDelegate already owns `text`,
    // `images`, `date` and `avatar`; a required property cannot redeclare them.

    ListModel {
        id: messagesModel

        Component.onCompleted: {
            const lorem = ("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do "
                         + "eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim "
                         + "ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut "
                         + "aliquip ex ea commodo consequat.").split(" ")

            const rows = []

            for (let i = 0; i < root.messageCount; i++) {
                const words = []
                const wordCount = 3 + (i * 7) % 60

                for (let w = 0; w < wordCount; w++)
                    words.push(lorem[(i + w) % lorem.length])

                const images = []
                const imageCount = i % 11 === 0 ? 1 + i % 3 : 0

                for (let j = 0; j < imageCount; j++)
                    images.push({ url: `https://picsum.photos/id/${(i + j) % 70}/1200/1300` })

                rows.push({
                    messageText: `**#${i}** ` + words.join(" "),
                    messageImages: images,
                    messageDate: new Date(2024, 0, 1 + i),
                    messageAvatar: `https://picsum.photos/id/${i % 70}/50/50`
                })
            }

            append(rows)
        }
    }

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        color: "#1b1b1f"

        Flickable {
            id: flickable

            anchors.fill: parent

            contentWidth: width
            contentHeight: messagesColumn.height

            ScrollBar.vertical: ScrollBar {}

            Column {
                id: messagesColumn

                width: flickable.width

                Repeater {
                    id: messagesRepeater

                    model: messagesModel

                    delegate: MessageDelegate {
                        id: messageItem

                        required property string messageText
                        required property var messageImages
                        required property date messageDate
                        required property string messageAvatar

                        width: messagesColumn.width
                        height: messageItem.implicitHeight

                        text: messageItem.messageText
                        images: messageItem.messageImages
                        date: messageItem.messageDate
                        avatar: messageItem.messageAvatar
                    }
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 280
        SplitView.preferredWidth: 320

        ColumnLayout {
            Layout.fillWidth: true

            spacing: 4

            Label {
                text: "View"
                font.bold: true
            }

            Label {
                text: "Items in the view: " + messagesRepeater.count
            }

            Label {
                text: "Items in the model: " + messagesModel.count
            }
        }
    }
}

// category: Panels
// status: good
