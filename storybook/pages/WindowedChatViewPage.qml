pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import "ChatViewPocComponents"

SplitView {
    id: root

    readonly property int initialMessageCount: 200

    // Sample data /////////////////////////////////////////////////////////////
    //
    // Deterministic on purpose - every reload gives the same heights, so what
    // the view does is comparable between runs. Each message carries its own
    // serial in the text, so an insertion is visible for what it is.
    //
    // The roles are prefixed because MessageDelegate already owns `text`,
    // `images`, `date` and `avatar`; a required property cannot redeclare them.

    QtObject {
        id: d

        readonly property var lorem:
            ("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor "
           + "incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis "
           + "nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo "
           + "consequat.").split(" ")

        property int nextSerial: 0

        function createMessage() {
            const i = d.nextSerial++

            const words = []
            const wordCount = 3 + (i * 7) % 60

            for (let w = 0; w < wordCount; w++)
                words.push(d.lorem[(i + w) % d.lorem.length])

            const images = []
            const imageCount = i % 11 === 0 ? 1 + i % 3 : 0

            for (let j = 0; j < imageCount; j++)
                images.push({ url: `https://picsum.photos/id/${(i + j) % 70}/1200/1300` })

            return {
                messageText: `**#${i}** ` + words.join(" "),
                messageImages: images,
                messageDate: new Date(2024, 0, 1 + i),
                messageAvatar: `https://picsum.photos/id/${i % 70}/50/50`
            }
        }

        function createMessages(count) {
            const rows = []

            for (let i = 0; i < count; i++)
                rows.push(d.createMessage())

            return rows
        }
    }

    // Inserts `count` freshly generated messages at `index`. Both ends are just
    // indices - 0 is the beginning, model.count the end - so there is one path
    // here regardless of what the panel asked for.
    function insertMessages(count, index) {
        const rows = d.createMessages(count)

        if (index >= messagesModel.count)
            messagesModel.append(rows)
        else
            messagesModel.insert(Math.max(0, index), rows)
    }

    ListModel {
        id: messagesModel

        Component.onCompleted: append(d.createMessages(root.initialMessageCount))
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

            Item { Layout.preferredHeight: 8 }

            Label {
                text: "Insert messages"
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true

                Label { text: "Count" }

                SpinBox {
                    id: countSpinBox

                    Layout.fillWidth: true

                    from: 1
                    to: 1000
                    value: 10
                    editable: true
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Label { text: "At" }

                ComboBox {
                    id: positionComboBox

                    Layout.fillWidth: true

                    model: ["End", "Beginning", "Index"]
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "Index"
                    enabled: indexSpinBox.enabled
                }

                SpinBox {
                    id: indexSpinBox

                    Layout.fillWidth: true

                    enabled: positionComboBox.currentValue === "Index"

                    from: 0
                    to: messagesModel.count
                    editable: true
                }
            }

            Button {
                Layout.fillWidth: true

                text: "Insert"

                onClicked: {
                    const index = {
                        "Beginning": 0,
                        "End": messagesModel.count,
                        "Index": indexSpinBox.value
                    }[positionComboBox.currentValue]

                    root.insertMessages(countSpinBox.value, index)
                }
            }
        }
    }
}

// category: Panels
// status: good
