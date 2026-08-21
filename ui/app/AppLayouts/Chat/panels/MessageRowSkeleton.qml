import QtQuick

import StatusQ.Components
import StatusQ.Core.Theme

// One message row's worth of skeleton: what a dense-model row shows while it
// is still a dummy, and while the fill that closed its hole is being dressed.
// Sized by its owner (the row holds the average row height), so the shape
// clips rather than reflows — a dummy must cost no layout work of its own.
LoadingSkeletonGroup {
    id: root

    clip: true

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Theme.halfPadding

        LoadingSkeletonTile {
            implicitWidth: 40
            implicitHeight: 40
            radius: width / 2
        }

        Column {
            spacing: 6

            LoadingSkeletonTile {
                implicitWidth: Math.max(0, (root.width - 40 - Theme.halfPadding) * 0.2)
                implicitHeight: 12
            }
            LoadingSkeletonTile {
                implicitWidth: Math.max(0, (root.width - 40 - Theme.halfPadding) * 0.85)
                implicitHeight: 14
            }
        }
    }
}
