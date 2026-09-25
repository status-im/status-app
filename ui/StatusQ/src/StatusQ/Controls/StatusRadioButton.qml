import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

RadioButton {
    id: root

    /*!
       \qmlproperty int StatusRadioButton::size
       This property holds size type of the radio button.
       Possible values are:
       - Small
       - Large (default size)
    */
    property int size: StatusRadioButton.Size.Large

    enum Size {
        Small,
        Large
    }

    opacity: enabled ? 1.0 : ThemeUtils.disabledOpacity
    font.family: Fonts.baseFont.family
    font.pixelSize: Theme.primaryTextFontSize

    indicator: Rectangle {
        implicitWidth: root.size === StatusRadioButton.Size.Large ? 20 : 14
        implicitHeight: root.size === StatusRadioButton.Size.Large ? 20 : 14
        x: root.text ? (root.mirrored ? root.width - width - root.rightPadding : root.leftPadding) : root.leftPadding + (root.availableWidth - width) / 2
        y: root.topPadding + (root.availableHeight - height) / 2
        radius: width / 2
        color: root.checked ? Theme.palette.primaryColor1 : Theme.palette.directColor8

        Rectangle {
            width: root.size === StatusRadioButton.Size.Large ? 12 : 8
            height: root.size === StatusRadioButton.Size.Large ? 12 : 8
            radius: width / 2
            anchors.centerIn: parent
            color: StatusColors.white
            visible: root.checked
        }
    }
    contentItem: StatusBaseText {
        font: root.font
        text: root.text
        color: Theme.palette.directColor1
        verticalAlignment: Text.AlignVCenter
        leftPadding: root.indicator && !root.mirrored ? root.indicator.width + root.spacing : 0
        rightPadding: root.indicator && root.mirrored ? root.indicator.width + root.spacing : 0
        visible: !!text
        wrapMode: Text.Wrap
    }
    HoverHandler {
        cursorShape: hovered ? Qt.PointingHandCursor : undefined
    }
}
