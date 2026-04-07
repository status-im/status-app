pragma ComponentBehavior: Bound

import QtQuick
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

Rectangle {
    id: statusDescriptionListItem

    property string title: ""
    property string subTitle: ""
    property alias subTitleComponent: statusDescriptionListItemSubTitle
    property string value: ""
    property StatusAssetSettings asset: StatusAssetSettings {
        width: 23
        height: 23
    }
    property alias tooltip: statusToolTip
    property alias iconButton: statusFlatRoundButton
    property alias sensor: sensor

    implicitWidth: 448
    implicitHeight: 56
    radius: 8

    color: Theme.palette.statusListItem.backgroundColor

    StatusMouseArea {
        id: sensor
        anchors.fill: parent
        hoverEnabled: true
        enabled: false
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        StatusBaseText {
            id: statusDescriptionListItemTitle
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.topMargin: 5
            anchors.right: parent.right
            anchors.rightMargin: 16

            color: Theme.palette.baseColor1
            text: statusDescriptionListItem.title
            font.pixelSize: Theme.additionalTextSize
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Row {
            anchors.top: statusDescriptionListItemTitle.bottom
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.topMargin: 4
            anchors.right: parent.right
            anchors.rightMargin: 16
            spacing: 4

            StatusBaseText {
                id: statusDescriptionListItemSubTitle
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - parent.spacing -
                                (statusFlatRoundButton.visible ? statusFlatRoundButton.width : 0) -
                                (valueRow.visible ? valueRow.width : 0))
                text: statusDescriptionListItem.subTitle
                color: Theme.palette.directColor1
                elide: Text.ElideRight
            }

            StatusFlatRoundButton {
                id: statusFlatRoundButton
                visible: !!statusDescriptionListItem.asset.name
                anchors.verticalCenter: parent.verticalCenter

                width: 32
                height: 32

                icon.name: statusDescriptionListItem.asset.name
                icon.width: statusDescriptionListItem.asset.width
                icon.height: statusDescriptionListItem.asset.height

                StatusToolTip {
                    id: statusToolTip
                }
            }
        }

        Row {
            id: valueRow
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            visible: !!statusDescriptionListItem.value
            spacing: 8

            StatusBaseText {
                text: statusDescriptionListItem.value
                color: Theme.palette.baseColor1
                font.pixelSize: Theme.primaryTextFontSize
                anchors.verticalCenter: parent.verticalCenter
            }

            StatusIcon {
                icon: "next"
                color: Theme.palette.baseColor1
            }
        }
    }
}
