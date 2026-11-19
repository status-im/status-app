import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

import utils

Control {
    id: root

    property alias image: image.source
    property alias title: title.text
    property alias subTitle: subTitle.text
    property bool closeEnabled: true

    // Dismisses the long-press state, e.g. when tapping outside the card.
    function reset() { d.closeVisible = false }

    signal clicked()
    signal close()

    QtObject {
        id: d
        // Touch screens: long-press pins the close button visible.
        property bool closeVisible: false
        property bool mouseHovered: false
        property bool pressedOnClose: false

        function isOverCloseButton(x, y) {
            return closeButton.visible && closeButton.contains(mouseArea.mapToItem(closeButton, x, y))
        }
    }

    implicitHeight: 70
    implicitWidth: 400
    padding: Theme.halfPadding
    leftPadding: 20

    background: StatusBackgroundPanel {
        radius: 12
        border.width: 1
        border.color: Theme.palette.baseColor2
    }
    contentItem: RowLayout {
        id: layout
        spacing: Theme.padding
        StatusImage {
            id: image
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            StatusBaseText {
                id: title
                Layout.fillWidth: true
                color: Theme.palette.directColor1
                font.pixelSize: Theme.additionalTextSize
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            StatusBaseText {
                id: subTitle
                Layout.fillWidth: true
                color: Theme.palette.baseColor1
                font.pixelSize: Theme.additionalTextSize
                elide: Text.ElideRight
            }
        }
        StatusIcon {
            id: closeButton
            objectName: "bannerCard_closeButton"
            Layout.topMargin: 4
            Layout.rightMargin: 4
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            icon: "close"
            color: d.mouseHovered && d.isOverCloseButton(mouseArea.mouseX, mouseArea.mouseY)
                   ? Theme.palette.directColor1 : Theme.palette.baseColor1
            visible: root.closeEnabled && (d.closeVisible || d.mouseHovered)
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton

        onPositionChanged: (mouse) => {
            if (!pressed && mouse.source === Qt.MouseEventNotSynthesized)
                d.mouseHovered = true
        }

        onExited: d.mouseHovered = false

        onPressed: (mouse) => {
            d.pressedOnClose = d.isOverCloseButton(mouse.x, mouse.y)
            if (mouse.source !== Qt.MouseEventNotSynthesized)
                d.mouseHovered = false
        }

        onPressAndHold: (mouse) => {
            if (mouse.source !== Qt.MouseEventNotSynthesized && !d.pressedOnClose)
                d.closeVisible = true
        }

        onClicked: (mouse) => {
            if (d.pressedOnClose) {
                if (d.isOverCloseButton(mouse.x, mouse.y)) {
                    d.closeVisible = false
                    root.close()
                }
                return
            }

            d.closeVisible = false
            root.clicked()
        }
    }
}
