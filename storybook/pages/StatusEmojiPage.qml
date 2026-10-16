import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components

Item {
    id: root

    readonly property var sampleSizes: [14, 18, 24, 32, 48, 72, 86]

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 40

        // The border is the box the component is given; the glyph should fill it.
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: sizeSlider.value
            Layout.preferredHeight: sizeSlider.value

            color: "transparent"
            border.width: 1
            border.color: "red"

            StatusEmoji {
                anchors.fill: parent
                emoji: emojiField.text
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 20

            Repeater {
                model: root.sampleSizes

                ColumnLayout {
                    spacing: 4

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: modelData
                        Layout.preferredHeight: modelData

                        color: "transparent"
                        border.width: 1
                        border.color: "red"

                        StatusEmoji {
                            anchors.fill: parent
                            emoji: emojiField.text
                        }
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: `${modelData}px`
                    }
                }
            }
        }
    }

    RowLayout {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 10

        spacing: 10

        Label {
            text: "emoji"
        }

        TextField {
            id: emojiField
            text: "😀"
        }

        Label {
            text: "size"
        }

        Slider {
            id: sizeSlider
            from: 8
            to: 200
            value: 86
            stepSize: 1
        }

        Label {
            text: `${sizeSlider.value}px`
        }
    }
}

// category: Components
