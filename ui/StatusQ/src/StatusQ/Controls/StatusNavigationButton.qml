import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

Button {
    id: root

    property color gradientColor: Theme.palette.statusAppLayout.backgroundColor
    property bool navigateForward: false
    property bool showIcon: true

    implicitWidth: root.showIcon ? height * 2 : Theme.bigPadding
    padding: 0
    hoverEnabled: true

    background: Rectangle {
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: navigateForward ? "transparent" : root.gradientColor }
            GradientStop { position: 1.0; color: navigateForward ? root.gradientColor : "transparent" }
        }
    }

    contentItem: Item {
        StatusIcon {
            icon: navigateForward ? "next" : "previous"
            anchors.right: navigateForward ? parent.right : undefined
            anchors.left: navigateForward ? undefined : parent.left
            width: parent.height
            height: width
            color: Theme.palette.primaryColor1
            visible: root.showIcon
        }

        // otherwise there is no pointing hand cursor when button is hovered
        StatusMouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
        }
    }
}
