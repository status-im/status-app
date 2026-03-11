import QtQuick

import StatusQ.Core.Theme

Item {
    id: root

    required property rect selectionStartRect
    required property rect selectionEndRect

    property int markerSize: 12
    property color color: Theme.palette.primaryColor1

    visible: selectionStartRect !== selectionEndRect

    component Marker: Rectangle {
        width: root.markerSize
        height: root.markerSize
        radius: root.markerSize / 2

        color: root.color
    }

    Rectangle {
        width: 2

        color: root.color

        Marker {
            anchors.bottom: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
        }

        x: selectionStartRect.x
        y: selectionStartRect.y
        height: selectionStartRect.height
    }

    Rectangle {
        width: 2

        color: root.color

        Item {
            width: root.markerSize
            height: root.markerSize / 2

            clip: true

            anchors.top: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter

            Marker {}
        }

        x: selectionEndRect.x
        y: selectionEndRect.y
        height: selectionEndRect.height
    }
}
