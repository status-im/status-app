import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import shared.status

Item {
    id: root

    readonly property string nameText: "Mr Pink"

    readonly property string messageText:
        "Oh wow! It looks wicked! We will use 3 lines max for quote. All dyna" +
        "mic text goes in one line and we’re only change style of text bla bla"

    Rectangle {
        anchors.fill: replyPanel
        anchors.margins: -10
        color: Theme.palette.background
        border.width: 1
        border.color: "lightgray"
    }

    StatusChatInputReplyPanel {
        id: replyPanel

        anchors.centerIn: parent
        width: Math.round(widthSlider.value * root.width / 100)

        nameText: (root.nameText + " ").repeat(nameLengthSlider.value)
        messageText: root.messageText.substring(0, messageLengthSlider.value)
        extraContentText: group.checkedButton.text === "None"
                          ? "" : group.checkedButton.text

        avatarImage: "https://i.pravatar.cc/128?img=45"
    }

    ColumnLayout {
        RowLayout {
            Slider {
                id: widthSlider

                from: 20
                to: 100

                value: 30
            }

            Label {
                text: `width: ${widthSlider.value}%`
            }
        }

        RowLayout {
            Slider {
                id: nameLengthSlider

                from: 1
                to: 5
                stepSize: 1
            }
            Label {
                text: `name size: ${Math.round(nameLengthSlider.value)}`
            }
        }

        RowLayout {
            Slider {
                id: messageLengthSlider

                from: 0
                to: root.messageText.length
                stepSize: 1

                value: to
            }

            Label {
                text: `message length: ${messageLengthSlider.value}`
            }
        }
    }

    GroupBox {
        title: "extra content"

        anchors.bottom: parent.bottom

        ButtonGroup {
            id: group

            buttons: buttons.children
        }

        ColumnLayout {
            id: buttons

            RadioButton {
                text: "None"
            }

            RadioButton {
                text: "5 Images"
            }

            RadioButton {
                text: "Sticker"
            }

            RadioButton {
                text: "Payment Request 2000 DAI"
                checked: true
            }
        }
    }
}

// category: Panels
// status: good
