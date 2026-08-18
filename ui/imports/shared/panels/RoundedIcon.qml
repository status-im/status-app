import QtQuick
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme

import utils
import "../"

Rectangle {
    id: root
    property alias source: roundedIconImage.source
    default property alias content: content.children
    property alias icon: roundedIconImage
    property bool rotates: false
    signal clicked
    width: 36
    height: 36
    property alias iconWidth: roundedIconImage.width
    property alias iconHeight: roundedIconImage.height
    property color iconColor: StatusColors.transparent

    color: Theme.palette.primaryColor1
    radius: width / 2

    Item {
        id: iconContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: roundedIconImage.width
        height: roundedIconImage.height

        SVGImage {
            id: roundedIconImage
            width: 12
            height: 12
            fillMode: Image.PreserveAspectFit
            source: Assets.svg("new_chat")
            rotation: root.rotation
        }
        ColorOverlay {
            anchors.fill: roundedIconImage
            source: roundedIconImage
            color: root.iconColor
            rotation: roundedIconImage.rotation
        }
    }

    Loader {
        active: rotates
        sourceComponent: rotatorComponent
    }

    Component {
        id: rotatorComponent
        RotationAnimator {
            target: iconContainer
            from: 0;
            to: 360;
            duration: 1200
            running: visible
            loops: Animation.Infinite
        }

    }

    Item {
        id: content
        anchors.left: iconContainer.right
        anchors.leftMargin: 6 + (root.width - iconContainer.width)
    }

    StatusMouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.clicked()
        }
    }
}

/*##^##
Designer {
    D{i:0;formeditorZoom:1.75}
}
##^##*/
