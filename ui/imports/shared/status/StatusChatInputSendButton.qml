import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

Control {
    id: root

    property string limitText
    property alias interactive: mouseArea.enabled

    signal clicked

    QtObject {
        id: d

        readonly property int implicitHeight: 36
        readonly property real hoverExpandFactor: 1.2
        readonly property real pressedExpandFactor: 1.1
    }

    contentItem: Item {
        implicitWidth: d.implicitHeight + Math.max(limitOutlineRectangle.width
                                                   - d.implicitHeight / 2, 0)
        implicitHeight: d.implicitHeight

        Rectangle {
            id: limitOutlineRectangle

            width: limitText.implicitWidth
                   + (baseBackgroundRectangle.width / 2 + Theme.halfPadding * 2)
                    * !!root.limitText
            height: parent.height
            clip: true

            anchors.right: baseBackgroundRectangle.horizontalCenter

            color: StatusColors.transparent

            Behavior on width {
                NumberAnimation {
                    duration: ThemeUtils.AnimationDuration.Fast
                    easing.type: Easing.InOutQuad
                }
            }

            topLeftRadius: height / 2
            bottomLeftRadius: topLeftRadius

            border.color: StatusColors.alphaColor(
                              Theme.palette.customisationColors.orange, 0.2)

            StatusBaseText {
                id: limitText

                x: Theme.halfPadding * 1.3

                opacity: !!text ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: ThemeUtils.AnimationDuration.Fast
                        easing.type: Easing.InOutQuad
                    }
                }

                anchors.bottom: parent.bottom
                anchors.top: parent.top

                verticalAlignment: Text.AlignVCenter

                text: root.limitText
                color: Theme.palette.customisationColors.orange

                font.pixelSize: Theme.additionalTextSize
                font.weight: Font.Medium
            }
        }

        Rectangle {
            anchors.centerIn: baseBackgroundRectangle

            smooth: true

            property real factor: mouseArea.pressed
                                  ? d.pressedExpandFactor
                                  : (mouseArea.containsMouse
                                     ? d.hoverExpandFactor : 1)

            width: baseBackgroundRectangle.width * factor
            height: width
            radius: width / 2

            color: baseBackgroundRectangle.color

            Behavior on factor {
                NumberAnimation {
                    duration: ThemeUtils.AnimationDuration.Fast
                    easing.type: Easing.InOutQuad
                }
            }
        }

        Rectangle {
            id: baseBackgroundRectangle

            width: parent.height

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: parent.top

            smooth: true
            color: root.enabled ? Theme.palette.primaryColor1
                                : Theme.palette.baseColor1
            radius: width / 2

            Behavior on color {
                ColorAnimation {
                    duration: ThemeUtils.AnimationDuration.Fast
                }
            }

            StatusIcon {
                id: sendButton

                anchors.centerIn: parent

                icon: "chat/up"
                color: Theme.palette.baseColor3
            }

            MouseArea {
                id: mouseArea

                anchors.fill: parent
                hoverEnabled: root.enabled

                cursorShape: Qt.PointingHandCursor

                onClicked: root.clicked()
            }
        }
    }
}
