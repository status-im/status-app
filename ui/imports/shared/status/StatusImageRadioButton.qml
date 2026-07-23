import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

import utils

RadioButton {
    id: root

    property url imageSource
    property size imageSize

    padding: Theme.halfPadding
    spacing: Theme.halfPadding
    hoverEnabled: enabled

    font.family: Fonts.baseFont.family
    font.pixelSize: Theme.fontSize(13)
    font.weight: checked ? Font.DemiBold : Font.Medium

    background: null

    contentItem: ColumnLayout {
        id: layout
        spacing: root.spacing

        Rectangle {
            Layout.preferredWidth: img.implicitWidth
            Layout.preferredHeight: img.implicitHeight
            Layout.alignment: Qt.AlignHCenter

            radius: 8
            color: StatusColors.transparent
            border.width: 2
            border.color: checked ? Theme.palette.primaryColor1 : hovered ? Theme.palette.primaryColor2
                                                                          : StatusColors.transparent

            Image {
                id: img
                anchors.fill: parent
                anchors.margins: 4
                mipmap: true
                antialiasing: true
                source: root.imageSource
                sourceSize: root.imageSize
            }
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
