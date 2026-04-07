pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme

Switch {
    id: root

    property color textColor: Theme.palette.directColor1

    font.family: Fonts.baseFont.family
    font.pixelSize: Theme.primaryTextFontSize

    background: null

    padding: 4
    opacity: enabled ? 1.0 : ThemeUtils.disabledOpacity

    property bool leftSide: true
    LayoutMirroring.enabled: !leftSide
    LayoutMirroring.childrenInherit: true

    indicator: Item {
        id: oval

        implicitWidth: 52
        implicitHeight: 28
        anchors.left: root.left
        anchors.leftMargin: root.leftPadding
        anchors.verticalCenter: root.verticalCenter

        Rectangle {
            anchors.fill: parent

            radius: 14
            color: root.checked ? Theme.palette.primaryColor1
                                : Theme.palette.directColor7
            Behavior on color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }
        }

        Rectangle {
            id: circle
            y: 4
            width: 20
            height: 20
            radius: 10
            color: StatusColors.white
            layer.enabled: true
            layer.effect: DropShadow {
                width: circle.width
                height: circle.height
                visible: true
                verticalOffset: 1
                fast: true
                cached: true
                color: Theme.palette.dropShadow
            }

            states: [
                State {
                    name: "on"
                    when: root.checked
                    PropertyChanges { target: circle; x: oval.width - circle.width - 4 }
                },
                State {
                    name: "off"
                    when: !root.checked
                    PropertyChanges { target: circle; x: 4 }
                }
            ]

            Behavior on x {
                enabled: !root.pressed
                SmoothedAnimation {}
            }
        }
    }

    contentItem: StatusBaseText {
        text: root.text
        color: root.textColor
        font: root.font
        verticalAlignment: Text.AlignVCenter
        leftPadding: root.mirrored ? 0 : !!root.text ? root.indicator.width + root.spacing : root.indicator.width
        rightPadding: root.mirrored ? !!root.text ? root.indicator.width + root.spacing : root.indicator.width : 0

        wrapMode: Text.WordWrap
        maximumLineCount: 3
        elide: Text.ElideRight
    }

    HoverHandler {
        cursorShape: root.enabled && root.hovered ? Qt.PointingHandCursor : undefined
    }
}
