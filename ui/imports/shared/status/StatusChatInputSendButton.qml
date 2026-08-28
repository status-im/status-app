import QtQuick
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

Control {
    id: root

    property string limitText
    property string iconName: "arrow-up"
    property alias interactive: mouseArea.enabled

    signal clicked

    QtObject {
        id: d

        readonly property int implicitHeight: 36
        readonly property int cornerRadius: 8
    }

    contentItem: Item {
        implicitWidth: d.implicitHeight + Math.max(limitOutlineRectangle.width
                                                   - d.implicitHeight / 2, 0)
        implicitHeight: d.implicitHeight

        FontMetrics {
            id: fontMetrics
            font: limitText.font
        }

        Rectangle {
            id: limitOutlineRectangle

            width: fontMetrics.averageCharacterWidth * root.limitText.length
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

            topLeftRadius: d.cornerRadius
            bottomLeftRadius: d.cornerRadius

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
            id: baseBackgroundRectangle

            width: parent.height

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.top: parent.top

            color: root.enabled ? Theme.palette.primaryColor1
                                : Theme.palette.baseColor1
            radius: d.cornerRadius

            Behavior on color {
                ColorAnimation {
                    duration: ThemeUtils.AnimationDuration.Fast
                }
            }

            StatusRipple {
                id: ripple

                objectName: "statusChatInputSendButtonRipple"
                anchors.fill: parent
                enabled: root.enabled && mouseArea.enabled
                color: Theme.palette.white
                radius: parent.radius
            }

            StatusIcon {
                id: sendButton

                anchors.centerIn: parent

                icon: root.iconName
                color: Theme.palette.white
            }

            MouseArea {
                id: mouseArea

                anchors.fill: parent
                hoverEnabled: root.enabled

                cursorShape: Qt.PointingHandCursor

                onPressed: mouse => ripple.press(mouse.x, mouse.y)
                onReleased: ripple.release()
                onCanceled: ripple.release()
                onClicked: root.clicked()
            }
        }
    }
}
