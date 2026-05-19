import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

StatusTextField {
    property bool showClearButton: text.length > 0
    property string iconName: "search"
    readonly property bool valid: acceptableInput

    placeholderText: qsTr("Search")

    leftPadding: Theme.halfPadding + searchIcon.width + searchIcon.anchors.leftMargin
    rightPadding: Theme.halfPadding + (clearButton.visible ? clearButton.width + clearButton.anchors.rightMargin : 0)

    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
    EnterKey.type: Qt.EnterKeySearch

    StatusIcon {
        id: searchIcon
        height: parent.height/2
        width: height
        anchors.left: parent.left
        anchors.leftMargin: Theme.halfPadding
        anchors.verticalCenter: parent.verticalCenter
        icon: parent.iconName
        color: Theme.palette.directColor1
    }

    StatusClearButton {
        id: clearButton
        height: parent.height/2
        width: height
        anchors.right: parent.right
        anchors.rightMargin: Theme.halfPadding
        anchors.verticalCenter: parent.verticalCenter
        visible: parent.showClearButton && parent.cursorVisible && !!parent.text
        onClicked: {
            parent.forceActiveFocus()
            parent.clear()
        }
    }
}
