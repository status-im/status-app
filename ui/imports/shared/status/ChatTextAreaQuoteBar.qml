import QtQuick

// Vertical quote-block bar drawn over a single quote group's "> " prefix column
// in ChatTextArea.
Rectangle {
    id: root

    // Fills the cell (so it blends with the input background), the thin bar
    // sits on top.
    property alias backgroundColor: root.color
    property color barColor

    property alias barWidth: bar.width

    Rectangle {
        id: bar

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: 3
        color: root.barColor

        bottomLeftRadius: width
        topLeftRadius: width
    }
}
