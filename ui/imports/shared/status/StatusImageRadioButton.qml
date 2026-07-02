import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

import utils

RadioButton {
    id: root

    property alias image: img

    padding: Theme.halfPadding
    spacing: Theme.halfPadding
    hoverEnabled: enabled

    font.family: Fonts.baseFont.family
    font.pixelSize: Theme.fontSize(13)
    font.weight: checked ? Font.DemiBold : Font.Medium

    background: Rectangle {
        radius: Theme.radius
        color: checked ? Theme.palette.secondaryBackground :
                         (hovered ? Theme.palette.backgroundHover : StatusColors.transparent)
        border.width: 2
        border.color: checked ? Theme.palette.primaryColor1 : StatusColors.transparent
    }

    contentItem: ColumnLayout {
        id: layout
        spacing: root.spacing

        Image {
            id: img
            Layout.fillWidth: true
            Layout.fillHeight: true
            fillMode: Image.PreserveAspectFit
            mipmap: true
            antialiasing: true
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Qt.AlignHCenter
            color: Theme.palette.baseColor1
            text: root.text
            font: root.font
        }
    }

    indicator: null

    HoverHandler {
        cursorShape: root.hovered ? Qt.PointingHandCursor : undefined
    }
}
