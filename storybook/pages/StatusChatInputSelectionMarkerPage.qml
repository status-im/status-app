import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Controls

import shared.status

Item {
    id: root

    StatusTextArea {
        id: inputArea

        anchors.centerIn: parent
        width: 400
        height: 200

        wrapMode: Text.Wrap
        font.pixelSize: fontSizeSlider.value

        text: "Lorem Ipsum is simply dummy text of the printing and typesetting" +
              " industry. Lorem Ipsum has been the industry's standard dummy text" +
              " ever since the 1500s, when an unknown printer took a galley of..."

        Component.onCompleted: {
            select(43, 189)
        }

        selectionColor: "gray"

        StatusChatInputSelectionMarker {
            anchors.fill: parent
            clip: true

            markerSize: inputArea.font.pixelSize

            selectionStartRect: {
                inputArea.font
                inputArea.positionToRectangle(inputArea.selectionStart)
            }
            selectionEndRect: {
                inputArea.font
                inputArea.positionToRectangle(inputArea.selectionEnd)
            }
        }
    }

    RowLayout {
        Slider {
            id: fontSizeSlider

            from: 10
            to: 50
            stepSize: 1

            value: 18
        }

        Label {
            text: "font size: " + (Math.round(fontSizeSlider.value) || "implicit")
        }
    }
}

// category: Controls
// status: good
