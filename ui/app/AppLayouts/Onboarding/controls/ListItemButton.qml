import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme

AbstractButton {
    id: root

    property string subTitle

    padding: Theme.padding
    spacing: Theme.padding

    icon.width: 32
    icon.height: 32

    hoverEnabled: enabled
    opacity: enabled ? 1.0 : ThemeUtils.disabledOpacity

    background: Rectangle {
        color: root.hovered ? Theme.palette.backgroundHover : "transparent"
        HoverHandler {
            cursorShape: root.hovered ? Qt.PointingHandCursor : undefined
        }
    }

    contentItem: RowLayout {
        spacing: root.spacing

        StatusImage {
            Layout.preferredWidth: root.icon.width
            Layout.preferredHeight: root.icon.height
            source: root.icon.source
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StatusBaseText {
                Layout.fillWidth: true
                text: root.text
                font.pixelSize: Theme.additionalTextSize
                font.weight: Font.Medium
                lineHeightMode: Text.FixedHeight
                lineHeight: 18
                wrapMode: Text.Wrap
            }
            StatusBaseText {
                Layout.fillWidth: true
                text: root.subTitle
                font.pixelSize: Theme.additionalTextSize
                visible: !!text
                lineHeightMode: Text.FixedHeight
                lineHeight: 18
                wrapMode: Text.Wrap
            }
        }

        StatusIcon {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            icon: "tiny/chevron-right"
            color: Theme.palette.directColor1
        }
    }
}
