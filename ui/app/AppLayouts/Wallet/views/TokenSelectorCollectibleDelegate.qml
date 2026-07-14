import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme

import utils

ItemDelegate {
    id: root
    objectName: "tokenSelectorCollectibleDelegate_" + name

    required property string name
    required property string balance
    required property url image
    required property string networkIcon
    required property bool isAutoHovered

    property bool goDeeperIconVisible: true
    property bool interactive: true

    spacing: Theme.halfPadding
    horizontalPadding: Theme.padding
    verticalPadding: 4

    opacity: interactive ? 1 : 0.3

    implicitWidth: ListView.view.width
    implicitHeight: 60

    icon.width: 32
    icon.height: 32
    // Default-token-icon fallback for empty media lives here at the leaf (the
    // Assets singleton is not reachable from the Nim picker model).
    icon.source: root.image != "" ? root.image : Assets.png(Constants.defaultTokenIcon)

    enabled: interactive

    background: Rectangle {
        radius: Theme.radius
        color: (root.interactive && (root.hovered || root.isAutoHovered ))
               ? Theme.palette.baseColor2
               : root.highlighted
                 ? Theme.palette.statusListItem.highlightColor
                 : "transparent"

        HoverHandler {
            cursorShape: root.interactive ? Qt.PointingHandCursor : undefined
        }
    }

    contentItem: RowLayout {
        spacing: root.spacing

        // asset icon
        StatusRoundedImage {
            Layout.preferredWidth: root.icon.width
            Layout.preferredHeight: root.icon.height
            image.source: root.icon.source
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            // name, symbol, total balance, network icon
            RowLayout {
                Layout.fillWidth: true
                spacing: root.spacing

                StatusBaseText {
                    id: nameText

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    text: root.name
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                StatusBaseText {
                    Layout.alignment: Qt.AlignVCenter

                    text: root.balance
                    visible: root.balance !== ""
                    color: Theme.palette.baseColor1
                    font.pixelSize: Theme.additionalTextSize
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                StatusRoundedImage {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20

                    image.source: Assets.svg(root.networkIcon)
                    visible:(root.hovered || root.isAutoHovered) && !root.goDeeperIconVisible
                }

                StatusIcon {
                    Layout.alignment: Qt.AlignVCenter

                    icon: "tiny/chevron-right"
                    visible: root.goDeeperIconVisible
                    color: Theme.palette.baseColor1
                    width: 16
                    height: 16
                }
            }
        }
    }
}
