import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking the community left column: the community
// header block followed by skeleton channel rows
LoadingSkeletonGroup {
    id: root

    ColumnLayout {
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
        }
        spacing: Theme.padding

        // Community banner/header block
        LoadingSkeletonTile {
            Layout.fillWidth: true
            implicitHeight: 45
            radius: Theme.radius
        }

        Repeater {
            model: 12
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.halfPadding

                LoadingSkeletonTile {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: width / 2
                }
                LoadingSkeletonTile {
                    Layout.fillWidth: true
                    implicitHeight: 22
                }
            }
        }
    }
}
