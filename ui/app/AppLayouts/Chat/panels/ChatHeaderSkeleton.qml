import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder for the chat header: avatar + name/subtitle lines
LoadingSkeletonGroup {
    id: root

    implicitWidth: 220
    implicitHeight: 40

    // Mirrors StatusChatInfoButton metrics (36px avatar, horizontalPadding 4,
    // avatar-to-text spacing 4, title/subtitle spacing 2) so the swap to the
    // real header doesn't shift anything.
    Row {
        anchors.verticalCenter: parent.verticalCenter
        // the real StatusChatInfoButton content sits 2px lower (verticalPadding)
        anchors.verticalCenterOffset: 2
        anchors.left: parent.left
        anchors.leftMargin: 4
        spacing: 4

        LoadingSkeletonTile {
            width: 36
            height: 36
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            LoadingSkeletonTile {
                width: 120
                height: 15
            }
            LoadingSkeletonTile {
                width: 80
                height: 10
            }
        }
    }
}
