import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

TextField {
    id: root

    property int displayIndex
    property bool valid: true

    leftPadding: fontMetrics.advanceWidth("24") + Theme.bigPadding
    rightPadding: Theme.halfPadding

    verticalAlignment: TextInput.AlignVCenter

    selectionColor: Theme.palette.primaryColor2
    selectedTextColor: color
    focus: !Utils.isMobile
    font.pixelSize: Theme.primaryTextFontSize
    font.family: Fonts.baseFont.family
    color: root.enabled ? Theme.palette.directColor1 : Theme.palette.baseColor1

    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText |
                      Qt.ImhNoAutoUppercase | Qt.ImhPreferLowercase

    background: Rectangle {
        id: background

        color: Theme.palette.statusAppNavBar.backgroundColor
        radius: Theme.radius

        StatusBaseText {
            id: text

            FontMetrics {
                id: fontMetrics
                font: text.font
            }

            anchors.fill: parent
            anchors.rightMargin: root.width - root.leftPadding

            text: "" + root.displayIndex
            font.family: Fonts.monoFont.family

            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter

            color: !root.valid ? Theme.palette.dangerColor1
                               : root.activeFocus ? Theme.palette.primaryColor1
                                                  : Theme.palette.baseColor1
        }

        border.width: 1
        border.color: {
            if (!root.valid)
                return Theme.palette.dangerColor1

            if (root.activeFocus)
                return Theme.palette.primaryColor1

            return root.hovered ? Theme.palette.primaryColor2 : "transparent"
        }
    }

    VirtualKeyboardBehaviorFix {}
}
