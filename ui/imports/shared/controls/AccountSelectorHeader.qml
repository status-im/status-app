import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

import utils

AccountSelector {
    id: root
    
    control.padding: 0
    control.rightInset: -6 //broken indicator positioning
    control.spacing: 4

    indicator.color: Theme.palette.indirectColor1

    control.background: Rectangle {
        objectName: "headerBackground"
        radius: 8
        color: d.headerStyleBackgroundColor

        HoverHandler {
            cursorShape: root.enabled ? Qt.PointingHandCursor : undefined
        }
    }

    contentItem: RowLayout {
        id: contentItemRow

        spacing: 0

        StatusSmartIdenticon {
            id: assetContent
            objectName: "assetContent"
            asset.emoji: !!currentAccount.emoji ? currentAccount.emoji : "👛" // Default to purse emoji
            asset.color: d.headerStyleBackgroundColor
            asset.width: 32
            asset.height: asset.width
            asset.isLetterIdenticon: true
            asset.bgColor: Theme.palette.primaryColor3
        }

        StatusBaseText {
            id: textContent
            objectName: "textContent"
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: currentAccount.name ?? ""
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: Utils.getContrastingColor(Theme.palette, d.headerStyleBackgroundColor)
        }
    }

    QtObject {
        id: d
        readonly property color headerStyleBackgroundColor: !!currentAccount ? root.control.hovered ?
                                        Utils.getHoveredColor(Theme.palette, currentAccount.colorId) :
                                        Utils.getColorForId(Theme.palette, currentAccount.colorId) : "transparent"
    }
}
