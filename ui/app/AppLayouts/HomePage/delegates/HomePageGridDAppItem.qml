import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Popups

import utils

HomePageGridItem {
    id: root

    property url connectorBadge

    signal disconnectRequested

    sectionType: Constants.appSection.dApp
    extraMenuActions: [disconnectAction]

    background: Rectangle {
        color: hovered ? Qt.lighter(Theme.palette.baseColor4, 1.5) : Theme.palette.baseColor4
        Behavior on color { ColorAnimation { duration: ThemeUtils.AnimationDuration.Fast } }
        radius: Theme.padding

        opacity: pressed || down ? ThemeUtils.pressedOpacity : enabled ? 1 : ThemeUtils.disabledOpacity
        Behavior on opacity { NumberAnimation { duration: ThemeUtils.AnimationDuration.Fast } }
    }

    iconLoaderComponent: StatusSmartIdenticon {
        asset.color: root.icon.color
        asset.bgColor: Qt.lighter(asset.color, 1.8)
        asset.name: root.icon.name
        asset.width: 30
        asset.height: 30

        name: root.title

        bridgeBadge {
            image.source: root.connectorBadge
            border.width: 0
            implicitHeight: 16
            implicitWidth: 16
            anchors.rightMargin: 1
            anchors.bottomMargin: 1
        }
        bridgeBadge.visible: root.connectorBadge != "" && !bridgeBadge.isError
    }

    bottomRowComponent: StatusBaseText {
        width: root.availableWidth
        text: root.itemId
        color: Theme.palette.baseColor1
        font.pixelSize: Theme.fontSize(12)
        font.weight: Font.Medium
        elide: Text.ElideRight

        HoverHandler {
            id: titleTextHHandler
            enabled: parent.truncated
        }
        StatusToolTip {
            visible: titleTextHHandler.hovered
            offset: -(x + width/2 - root.width/2)
            text: root.itemId
        }
    }

    StatusAction {
        id: disconnectAction
        objectName: "disconnectAction"
        icon.name: "disconnect"
        text: qsTr("Disconnect")
        onTriggered: root.disconnectRequested()
    }
}
