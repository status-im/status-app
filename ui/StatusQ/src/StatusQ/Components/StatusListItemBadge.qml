pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import StatusQ.Core
import StatusQ.Core.Theme

Control {
    id: root
    implicitWidth: contentItem.width
    implicitHeight: visible ? 22 : 0
    visible: !!root.primaryText

    property string primaryText: ""
    property string secondaryText: ""

    property StatusAssetSettings asset: StatusAssetSettings {
        height: 16
        width: 16
        isLetterIdenticon: false
        color: "transparent"
        imgIsIdenticon: false
    }

    background: Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: 11
        border.color: Theme.palette.directColor7
    }

    contentItem: Item {
        id: contentItem
        width: (contentItemRow.width + 10)
        height: parent.height
        RowLayout {
            id: contentItemRow
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: -spacing
            spacing: 2
            StatusRoundedImage {
                implicitWidth: root.asset.width
                implicitHeight: root.asset.height
                visible: !root.asset.isLetterIdenticon
                image.source: root.asset.name
                border.color: Theme.palette.baseColor1
                border.width: root.asset.imgIsIdenticon ? 1 : 0
            }
            StatusLetterIdenticon {
                implicitWidth: root.asset.width
                implicitHeight: root.asset.width
                letterSize: 11
                visible: root.asset.isLetterIdenticon
                letterIdenticonColor: root.asset.color
                name: root.primaryText
                emoji: root.asset.emoji
                emojiSize: root.asset.emojiSize
            }
            StatusBaseText {
                font.weight: Font.Medium
                color: Theme.palette.baseColor1
                text: root.primaryText
            }
            StatusIcon {
                Layout.alignment: Qt.AlignVCenter
                visible: !!root.secondaryText
                color: Theme.palette.baseColor1
                icon: "next"
            }
            StatusBaseText {
                font.weight: Font.Medium
                color: Theme.palette.baseColor1
                visible: !!root.secondaryText
                text: root.secondaryText
            }
        }
    }
}
