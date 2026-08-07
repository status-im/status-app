import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking the chat members panel: the "Members" label
// area followed by skeleton member rows (avatar + name)
LoadingSkeletonGroup {
    id: root

    ColumnLayout {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: Theme.padding

        LoadingSkeletonTile {
            implicitWidth: 80
            implicitHeight: 16
        }

        Repeater {
            model: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.halfPadding

                LoadingSkeletonTile {
                    implicitWidth: 34
                    implicitHeight: 34
                    radius: width / 2
                }
                LoadingSkeletonTile {
                    implicitWidth: 130
                    implicitHeight: 12
                }
            }
        }
    }
}
