import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme
import utils
import shared.status

Item {
    id: root

    Rectangle {
        anchors.fill: chatToolbar
        anchors.margins: -10
        color: Theme.palette.background
    }

    StatusChatInputToolBar {
        id: chatToolbar

        sendButtonVisible: sendButtonVisibleCheckBox.checked

        sendButton.enabled: enabledCheckBox.checked
        sendButton.limitText: limitSlider.value > 0 ? limitSlider.value.toString() : ""

        width: widthSlider.value || undefined

        anchors.centerIn: parent
    }

    Tracer {
        anchors.fill: chatToolbar
        anchors.margins: -10
    }

    ColumnLayout {
        RowLayout {
            Slider {
                id: widthSlider

                from: 0
                to: 800
                stepSize: 1
            }

            Label {
                text: "width: " + (widthSlider.value || "implicit")
            }
        }

        CheckBox {
            id: sendButtonVisibleCheckBox

            text: "send button visible"
            checked: true
        }

        RowLayout {
            Slider {
                id: limitSlider

                from: 0
                to: 2500
                stepSize: 1
            }

            Label {
                text: "send button limit: " + limitSlider.value
            }
        }

        CheckBox {
            id: enabledCheckBox

            text: "send button enabled"
            checked: true
        }
    }
}

// category: Controls
// status: good
