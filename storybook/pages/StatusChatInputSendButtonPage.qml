import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import shared.status

Item {
    id: root

    Rectangle {
        anchors.fill: sendButton
        anchors.margins: -50

        color: Theme.palette.background
        border.width: 1
    }

    StatusChatInputSendButton {
        id: sendButton

        anchors.centerIn: parent

        enabled: enabledCheckBox.checked
        limitText: limitSlider.value > 0 ? limitSlider.value.toString() : ""

        property int clickCounter

        onClicked: clickCounter++
    }

    ColumnLayout {
        RowLayout {
            Slider {
                id: limitSlider

                from: 0
                to: 2500
                stepSize: 1
            }

            Label {
                text: "limit: " + limitSlider.value
            }
        }

        CheckBox {
            id: enabledCheckBox

            text: "enabled"
            checked: true
        }


        Label {
            text: "clicked: " + sendButton.clickCounter
        }
    }
}

// category: Controls
// status: good
