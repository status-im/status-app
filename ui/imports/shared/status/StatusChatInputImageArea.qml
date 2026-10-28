import QtQuick
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import utils
import shared
import shared.panels

Row {
    id: imageArea
    spacing: Theme.halfPadding

    signal imageRemoved(int index)
    signal imageClicked(var chatImage)

    property bool leftTail: true

    property alias imageSource: rptImages.model

    Repeater {
        id: rptImages

        Item {
            height: chatImage.height
            width: chatImage.width

            // Decoded for its size, not the full photo: a share can attach
            // dozens of camera images and full decodes exhaust memory. The
            // callout's shape, as CalloutCard's, is cut in the pass drawing
            // the image: no layer.
            StatusRoundedImage {
                id: chatImage
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                width: 64
                height: 64
                asynchronous: true
                cache: false
                source: modelData
                fillMode: Image.PreserveAspectCrop
                radius: Theme.radius * 2
                bottomLeftRadius: imageArea.leftTail ? Theme.radius / 2 : Theme.radius * 2
                bottomRightRadius: imageArea.leftTail ? Theme.radius * 2 : Theme.radius / 2
                unsetBorderWidth: 0
            }

            StatusMouseArea {
                id: mouseArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: imageArea.imageClicked(chatImage)
            }

            RoundButton {
                id: closeBtn
                width: 24
                height: 24
                padding: 0
                anchors.right: chatImage.right
                anchors.rightMargin: -width / 3
                anchors.top: chatImage.top
                anchors.topMargin: -height / 3
                hoverEnabled: false
                opacity: SQUtils.Utils.isMobile || mouseArea.containsMouse || buttonMouseArea.containsMouse ? 1 : 0
                contentItem: SVGImage {
                    source: Assets.svg( !buttonMouseArea.containsMouse ? "close-filled" : "close-filled-hovered")
                    width: closeBtn.width
                    height: closeBtn.height
                }
                background: Rectangle {
                    color: "transparent"
                }
                onClicked: {
                    imageArea.imageRemoved(index)
                }
                StatusMouseArea {
                    id: buttonMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: closeBtn.clicked()
                }
            }
        }
    }
}
