import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components

import utils

ColumnLayout {
    id: root

    property string caption
    property string primaryText
    property color primaryTextCustomColor: Theme.palette.directColor1
    property string secondaryText
    property string icon
    property string badge
    property alias asset: listItem.asset
    property alias components: listItem.components
    property int listItemHeight: 76
    property bool highlighted

    StatusBaseText {
        text: root.caption
        font.pixelSize: Theme.additionalTextSize
    }
    StatusListItem {
        id: listItem
        Layout.fillWidth: true
        Layout.preferredHeight: root.listItemHeight
        title: root.primaryText
        statusListItemTitle.font.pixelSize: Theme.additionalTextSize
        statusListItemTitle.elide: Text.ElideMiddle
        statusListItemTitle.customColor: root.primaryTextCustomColor
        statusListItemTitle.textFormat: Text.PlainText
        subTitle: root.secondaryText
        statusListItemSubTitle.font.pixelSize: Theme.additionalTextSize
        statusListItemSubTitle.textFormat: Text.PlainText
        asset.name: root.icon
        asset.isImage: true
        asset.bgWidth: 40
        asset.bgHeight: 40
        border.width: 1
        border.color: Theme.palette.baseColor2
        highlighted: root.highlighted

        sensor.enabled: false

        statusListItemIcon.bridgeBadge.width: 16
        statusListItemIcon.bridgeBadge.height: 16
        statusListItemIcon.bridgeBadge.border.width: 1
        statusListItemIcon.bridgeBadge.image.source: root.badge
        statusListItemIcon.bridgeBadge.visible: !!root.badge
    }
}
