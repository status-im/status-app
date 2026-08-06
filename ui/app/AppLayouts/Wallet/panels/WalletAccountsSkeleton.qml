import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking the wallet left panel: the "All accounts"
// summary card followed by account list items
LoadingSkeletonGroup {
    id: root

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: Theme.smallPadding

        StatusBaseText {
            id: walletTitleText
            text: qsTr("Wallet")
            font.weight: Font.Bold
            font.pixelSize: Theme.secondaryAdditionalTextSize
            color: Theme.palette.directColor1
        }

        // "All accounts" summary card
        LoadingSkeletonTile {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.halfPadding
            implicitHeight: 86
            radius: Theme.radius
        }

        // account list items
        Repeater {
            model: 8
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.padding
                Layout.preferredHeight: 64
                spacing: Theme.padding

                LoadingSkeletonTile {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: width / 2
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.halfPadding

                    LoadingSkeletonTile {
                        implicitWidth: 120
                        implicitHeight: 14
                    }
                    LoadingSkeletonTile {
                        implicitWidth: 80
                        implicitHeight: 12
                    }
                }
            }
        }
    }
}
