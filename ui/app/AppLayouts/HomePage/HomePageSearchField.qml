import QtQuick
import QtQuick.Controls

import StatusQ.Controls
import StatusQ.Core.Theme

StatusTextField {
    leftPadding: 0
    rightPadding: 0
    topPadding: 12
    bottomPadding: 12
    background: null
    font.pixelSize: Theme.fontSize(27)
    font.weight: Font.DemiBold
    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData

    StatusClearButton {
        anchors.right: parent.right
        anchors.rightMargin: parent.rightPadding
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: 32
        visible: parent.text
        icon.width: 24
        icon.height: 24
        onClicked: {
            parent.forceActiveFocus()
            parent.clear()
        }
    }
}
