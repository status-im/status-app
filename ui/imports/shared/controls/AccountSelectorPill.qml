import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils as SQUtils

import utils

AbstractButton {
    id: root

    property string name
    property string emoji
    property string colorId
    property string address

    readonly property string displayText: !!name ? name
                        : (!!address ? SQUtils.Utils.elideAndFormatWalletAddress(address) : "")

    padding: 4
    horizontalPadding: 8

    implicitWidth: implicitContentWidth + leftPadding + rightPadding
    implicitHeight: implicitContentHeight + topPadding + bottomPadding

    background: Rectangle {
        objectName: "accountPillBackground"
        radius: 8
        color: d.pillColor

        HoverHandler {
            cursorShape: root.enabled ? Qt.PointingHandCursor : undefined
        }
    }

    contentItem: RowLayout {
        spacing: 4
        clip: true

        StatusSmartIdenticon {
            objectName: "accountPillIdenticon"
            asset.emoji: !!root.emoji ? root.emoji : "👛"
            asset.color: d.pillColor
            asset.width: 24
            asset.height: asset.width
            asset.isLetterIdenticon: true
            asset.bgColor: Theme.palette.primaryColor3
        }

        StatusBaseText {
            Layout.fillWidth: true
            Layout.fillHeight: true
            objectName: "accountPillText"
            text: root.displayText
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: Utils.getContrastingColor(Theme.palette, d.pillColor)
            font.weight: Font.Medium
        }
    }

    QtObject {
        id: d
        readonly property color pillColor: !!root.colorId
                ? (root.hovered ? Utils.getHoveredColor(Theme.palette, root.colorId)
                                : Utils.getColorForId(Theme.palette, root.colorId))
                : Theme.palette.primaryColor1
    }
}
