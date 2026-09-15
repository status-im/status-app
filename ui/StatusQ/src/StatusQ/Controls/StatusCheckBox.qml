import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

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
    opacity: enabled ? 1.0 : ThemeUtils.disabledOpacity

    QtObject {
        id: d

        readonly property int indicatorSizeRegular: 18
        readonly property int indicatorSizeSmall: 12

        readonly property int indicatorIconWidthRegular: 11
        readonly property int indicatorIconWidthSmall: 7

        readonly property int indicatorIconHeightRegular: 8
        readonly property int indicatorIconHeightSmall: 5
    }

    font.family: Fonts.baseFont.family
    font.pixelSize: size === StatusCheckBox.Size.Regular ? Theme.primaryTextFontSize : Theme.additionalTextSize

    indicator: Rectangle {
        objectName: "indicator"
        anchors.left: root.left
        anchors.leftMargin: root.leftPadding
        anchors.verticalCenter: root.verticalCenter
        implicitWidth: size === StatusCheckBox.Size.Regular
                       ? d.indicatorSizeRegular : d.indicatorSizeSmall
        implicitHeight: implicitWidth
        radius: 2
        color: checkState !== Qt.Checked ? Theme.palette.directColor7 : Theme.palette.primaryColor1
        Behavior on color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }

        StatusIcon {
            icon: "checkbox"
            width: size === StatusCheckBox.Size.Regular
                   ? d.indicatorIconWidthRegular : d.indicatorIconWidthSmall
            height: size === StatusCheckBox.Size.Regular
                    ? d.indicatorIconHeightRegular : d.indicatorIconHeightSmall
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.mirrored ? - 1 : 1
            color: checkState === Qt.PartiallyChecked ? Theme.palette.directColor9 : StatusColors.white
            opacity: checkState !== Qt.Unchecked ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { OpacityAnimator { duration: ThemeUtils.AnimationDuration.Fast } }
        }
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
    }

    HoverHandler {
        cursorShape: root.changeCursor && hovered ? Qt.PointingHandCursor : undefined
    }
}
