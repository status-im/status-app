import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls.private

CheckBox {
    id: root

    /*!
       \qmlproperty int StatusCheckBox::size
       This property holds size type of the radio button.
       Possible values are:
       - Small
       - Regular (default size)
    */
    property int size: StatusCheckBox.Size.Regular
    property bool changeCursor: true

    enum Size {
        Small,
        Regular
    }

    property bool leftSide: true
    LayoutMirroring.enabled: !leftSide
    LayoutMirroring.childrenInherit: true

    padding: 4

    font.family: Fonts.baseFont.family
    font.pixelSize: size === StatusCheckBox.Size.Regular ? Theme.primaryTextFontSize : Theme.additionalTextSize

    hoverEnabled: enabled

    indicator: StatusCheckIndicator {
        objectName: "indicator"
        anchors.left: root.left
        anchors.leftMargin: root.leftPadding
        anchors.verticalCenter: root.verticalCenter
        checkState: root.checkState
        mirrored: root.mirrored
        hovered: root.hovered
        enabled: root.enabled
        size: root.size
    }

    contentItem: StatusBaseText {
        text: root.text
        font: root.font
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        width: root.availableWidth
        lineHeight: 1.2
        leftPadding: root.mirrored ? 0 : !!root.text ? root.indicator.width + root.spacing : root.indicator.width
        rightPadding: root.mirrored ? !!root.text ? root.indicator.width + root.spacing : root.indicator.width : 0
        color: root.enabled ? Theme.palette.directColor1 : Theme.palette.baseColor1
    }

    HoverHandler {
        cursorShape: root.changeCursor && hovered ? Qt.PointingHandCursor : undefined
    }
}
