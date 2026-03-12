import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Components

Item {
    Flow {
        anchors.fill: parent
        anchors.margins: 20

        spacing: 30

        Repeater {
            model: 101

            StatusBadge {
                value: modelData
                border.width: borderSlider.value
                border.color: color
            }
        }
    }

    RowLayout {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 10

        spacing: 10

        Label {
            text: "border width"
        }

        Slider {
            id: borderSlider
            from: 0
            to: 12
            value: 0
            stepSize: 1
        }

        Label {
            text: borderSlider.value
        }
    }
}

// category: Components
