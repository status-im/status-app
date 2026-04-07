pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

ItemDelegate {
    id: root

    property bool centerTextHorizontally: false
    property int radius: 0
    property int cursorShape: Qt.PointingHandCursor
    property color highlightColor: Theme.palette.statusMenu.hoverBackgroundColor

    padding: Theme.halfPadding
    spacing: Theme.halfPadding

    icon.width: 16
    icon.height: 16

    font.family: Fonts.baseFont.family
    font.pixelSize: Theme.primaryTextFontSize

    contentItem: RowLayout {
        spacing: root.spacing

        StatusIcon {
            Layout.alignment: Qt.AlignVCenter
            visible: !!icon
            icon: root.icon.name || root.icon.source
            color: root.enabled ? root.icon.color : Theme.palette.baseColor1
            width: root.icon.width
            height: root.icon.height
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            font: root.font
            text: root.text
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: root.highlighted ? StatusColors.white : root.enabled ? Theme.palette.directColor1 : Theme.palette.baseColor1

            Binding on horizontalAlignment {
                when: root.centerTextHorizontally
                value: Text.AlignHCenter
            }
        }
    }

    background: Rectangle {
        color: root.highlighted ? root.highlightColor : "transparent"
        radius: root.radius
    }

    HoverHandler {
        cursorShape: hovered ? root.cursorShape : undefined
    }
}
