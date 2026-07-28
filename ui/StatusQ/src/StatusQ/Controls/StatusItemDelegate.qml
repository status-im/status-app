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
    property int rippleOrigin: StatusRipple.RippleOrigin.Pointer

    padding: Theme.halfPadding
    spacing: Theme.halfPadding

    icon.width: 16
    icon.height: 16

    font.family: Fonts.baseFont.family
    font.pixelSize: Theme.primaryTextFontSize

    QtObject {
        id: d

        readonly property bool highlightedWithPrimaryColor: root.highlighted &&
                                                           Qt.colorEqual(root.highlightColor, Theme.palette.primaryColor1)
        readonly property color contentColor: !root.enabled ? Theme.palette.baseColor1 :
                                                d.highlightedWithPrimaryColor ? StatusColors.white :
                                                                                Theme.palette.directColor1
    }

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
            color: d.contentColor

            Binding on horizontalAlignment {
                when: root.centerTextHorizontally
                value: Text.AlignHCenter
            }
        }
    }

    background: Rectangle {
        color: root.highlighted ? root.highlightColor : "transparent"
        radius: root.radius

        StatusRipple {
            id: itemDelegateRipple
            objectName: "statusItemDelegateRipple"
            anchors.fill: parent
            enabled: root.enabled
            color: d.contentColor
            radius: parent.radius
            origin: root.rippleOrigin
            button: root
        }
    }

    HoverHandler {
        cursorShape: hovered ? root.cursorShape : undefined
    }
}
