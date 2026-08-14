import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import utils
import shared
import shared.panels

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

Rectangle {
    id: root

    property var buttonGroup
    property string btnText: "change me"
    property bool checkedByDefault: false

    signal checked()
    signal toggled(bool checked)

    function toggle() {
        radioBtn.toggle()
    }

    border.color: mouseArea.containsMouse || radioBtn.checked ? Theme.palette.primaryColor1 : Theme.palette.border
    border.width: 1
    color: StatusColors.transparent
    implicitWidth: 130
    implicitHeight: 120
    radius: Theme.radius

    StatusRadioButton {
        id: radioBtn
        ButtonGroup.group: buttonGroup
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 14
        checked: root.checkedByDefault
        onCheckedChanged: {
            if (checked) {
                root.checked()
            }
        }
    }

    StatusBaseText {
        id: txt
        text: btnText
        anchors.rightMargin: Theme.padding
        anchors.leftMargin: Theme.padding
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: radioBtn.bottom
        anchors.topMargin: 6
        wrapMode: Text.WordWrap
    }

    StatusMouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (radioBtn.checked)
                return
            radioBtn.toggle()
            root.toggled(radioBtn.checked)
        }
    }
}
