import QtQuick
import QtQuick.Controls
import QtQuick.Effects

import StatusQ.Core.Theme

/*!
  /note beware, the slider processes the mouse events only in its control space. So it must be at least as high
  as the /c handle so user can grab it fully.
 */
Slider {
    id: root

    property int handleSize: 28
    property int bgHeight: handleSize/2
    property color handleColor: StatusColors.white
    property color bgColor: Theme.palette.baseColor2
    property color fillColor: Theme.palette.primaryColor1

    property alias decoration: decorationContainer.sourceComponent

    horizontalPadding: 0

    background: Item {
        Rectangle {
            id: bgRect

            anchors.verticalCenter: parent.verticalCenter

            x: root.handle.width / 2
            width: parent.width - root.handle.width
            height: root.bgHeight

            color: root.bgColor
            radius: height

            Loader {
                id: decorationContainer
                anchors.top: parent.top
                width: parent.width
            }

            Rectangle {
                width: root.visualPosition * parent.width
                height: parent.height
                color: root.fillColor
                radius: height
            }
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        anchors.verticalCenter: parent.verticalCenter
        color: root.handleColor
        implicitWidth: root.handleSize
        implicitHeight: root.handleSize
        radius: root.handleSize / 2

        // The shadow is computed by Qt's RectangularShadow shader, behind the
        // handle: no layer, no blur passes
        RectangularShadow {
            anchors.fill: parent
            z: -1
            radius: parent.radius
            offset.y: 2
            blur: 24
            color: Theme.palette.dropShadow3
        }
    }

    HoverHandler {
        cursorShape: root.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    }
}
