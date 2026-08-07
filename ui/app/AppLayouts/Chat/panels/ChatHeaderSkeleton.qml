import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder for the chat header: avatar + name/subtitle lines
LoadingSkeletonGroup {
    id: root

    implicitWidth: 220
    implicitHeight: 40

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.halfPadding

        LoadingSkeletonTile {
            width: 32
            height: 32
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.halfPadding / 2

            LoadingSkeletonTile {
                width: 120
                height: 14
            }
            LoadingSkeletonTile {
                width: 80
                height: 10
            }
        }
    }
}
