import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder for the chat input area: rounded text field with its
// action buttons row below. Use only where the real StatusChatInput is not
// on screen. Plain positioners on purpose — skeletons must stay near-free,
// QtQuick.Layouts polish is too expensive here.
LoadingSkeletonGroup {
    id: root

    implicitHeight: inputColumn.implicitHeight

    Column {
        id: inputColumn

        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: Theme.halfPadding

        LoadingSkeletonTile {
            width: parent.width
            height: 48
            radius: Theme.radius
        }
        Item {
            width: parent.width
            height: 32

            Row {
                spacing: Theme.halfPadding

                Repeater {
                    model: 6
                    LoadingSkeletonTile {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Theme.radius
                    }
                }
            }
            LoadingSkeletonTile {
                anchors.right: parent.right
                implicitWidth: 32
                implicitHeight: 32
                radius: width / 2
            }
        }
    }
}
