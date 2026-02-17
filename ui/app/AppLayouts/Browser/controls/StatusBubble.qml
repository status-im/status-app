import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

Rectangle {
    id: root

    property alias text: statusText.text

    color: Theme.palette.baseColor2
    visible: text !== ""
    width: Math.min(statusText.implicitWidth, parent ? parent.width : 300)
    height: statusText.implicitHeight

    function show(hoveredUrl) {
        if (hoveredUrl === "") {
            hideTimer.start()
        } else {
            statusText.text = hoveredUrl
            hideTimer.stop()
        }
    }

    StatusBaseText {
        id: statusText
        anchors.fill: parent
        verticalAlignment: Qt.AlignVCenter
        elide: Qt.ElideMiddle
        padding: 4
    }

    Timer {
        id: hideTimer
        interval: 750
        onTriggered: statusText.text = ""
    }
}
