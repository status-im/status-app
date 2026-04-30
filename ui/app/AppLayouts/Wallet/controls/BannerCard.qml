import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

import StatusQ.Components
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
    }

    implicitHeight: 70
    implicitWidth: 400
    padding: Theme.halfPadding
    leftPadding: 20

    TapHandler {
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        enabled: !closeHandler.pressed
        onTapped: root.clicked()
    }

    // Long press (touch screens): pins the close button visible.
    // exclusiveSignals ensures tapped and longPressed are mutually exclusive.
    TapHandler {
        acceptedDevices: PointerDevice.TouchScreen
        exclusiveSignals: TapHandler.SingleTap | TapHandler.LongPress
        enabled: !closeHandler.pressed
        onTapped: {
            d.closeVisible = false
            root.clicked()
        }
        onLongPressed: d.closeVisible = true
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    background: Rectangle {
        id: background
        color: Theme.palette.background
        radius: 12
        border.width: 1
        border.color: Theme.palette.baseColor2
        layer.enabled: true
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 7
            radius: 8
            spread: root.hovered ? 0.3 : 0
            color: Theme.palette.baseColor2
        }
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
            color: closeHoverHandler.hovered ? Theme.palette.directColor1 : Theme.palette.baseColor1
            visible: root.closeEnabled && (d.closeVisible || root.hovered)
            TapHandler {
                id: closeHandler
                acceptedButtons: Qt.LeftButton
                onTapped: {
                    d.closeVisible = false
                    root.close()
                }
            }
            HoverHandler {
                id: closeHoverHandler
            }
        }
    }
}
