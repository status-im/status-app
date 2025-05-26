import QtQuick 2.15

Item {
    property alias model: wordsRepeater.model

    implicitHeight: childrenRect.height + 32

    Rectangle {
        id: avatar

        x: 16
        y: 16
        color: "#343438"
        width: 40
        height: 40

        radius: 20
    }

    Rectangle {
        id: title

        anchors.left: avatar.right
        anchors.leftMargin: 16
        anchors.top: avatar.top
        color: "#404045"
        width: 140
        height: 14
        radius: 20
    }

    Flow {
        anchors.top: title.bottom
        anchors.topMargin: 8
        anchors.left: avatar.right
        anchors.leftMargin: 16
        anchors.right: parent.right

        spacing: 5

        Repeater {
            id: wordsRepeater

            Rectangle {
                x: 81
                y: 16
                color: "#343438"
                width: modelData
                height: 14

                radius: 20
            }
        }
    }
}
