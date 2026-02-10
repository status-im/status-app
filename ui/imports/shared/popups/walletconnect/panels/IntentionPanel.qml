import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

import utils

ColumnLayout {
    id: root

    spacing: 8

    required property string dappName
    required property url dappIcon
    required property var account

    property string userDisplayNaming

    // Icons
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        Layout.alignment: Qt.AlignHCenter
        Layout.bottomMargin: 8

        StatusRoundedImage {
            width: height
            height: parent.height

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: -16
            anchors.verticalCenter: parent.verticalCenter

            image.source: root.dappIcon
        }
        StatusRoundIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.horizontalCenterOffset: 16
            anchors.verticalCenter: parent.verticalCenter

            asset: StatusAssetSettings {
                width: 24
                height: 24
                color: root.Theme.palette.primaryColor1
                bgWidth: 40
                bgHeight: 40
                bgColor: root.Theme.palette.desktopBlue10
                bgRadius: bgWidth / 2
                bgBorderWidth: 2
                bgBorderColor: root.Theme.palette.statusAppLayout.backgroundColor
                source: Assets.svg("sign")
            }
        }
    }

    // Names and intentions
    StatusBaseText {
        text: qsTr("%1 wants you to %2 with %3").arg(dappName).arg(root.userDisplayNaming).arg(account.name)

        Layout.preferredWidth: 400
        Layout.alignment: Qt.AlignHCenter

        font.pixelSize: Theme.primaryTextFontSize
        font.weight: Font.DemiBold

        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    // TODO #14762: externalize as a InfoPill and merge base implementation with
    // the existing IssuePill reusable component
    Rectangle {
        Layout.preferredWidth: operationStatusLayout.implicitWidth + 24
        Layout.preferredHeight: operationStatusLayout.implicitHeight + 14

        Layout.alignment: Qt.AlignHCenter

        visible: true

        border.color: Theme.palette.successColor2
        border.width: 1
        color: "transparent"
        radius: height / 2

        RowLayout {
            id: operationStatusLayout

            spacing: 8

            anchors.centerIn: parent

            StatusIcon {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16

                visible: true

                color: Theme.palette.directColor1
                icon: "info"
            }

            StatusBaseText {
                text: qsTr("Only sign if you trust the dApp")

                font.pixelSize: Theme.tertiaryTextFontSize
                color: Theme.palette.directColor1
            }
        }
    }
}
