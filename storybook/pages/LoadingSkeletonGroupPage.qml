import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

SplitView {
    id: root

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Item {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            // primitives: arbitrary tile arrangements sharing one shimmer sweep
            LoadingSkeletonGroup {
                anchors.centerIn: parent
                width: 320
                height: 260
                visible: visibleSwitch.checked

                Column {
                    spacing: Theme.padding

                    Repeater {
                        model: 4

                        Row {
                            spacing: Theme.halfPadding

                            LoadingSkeletonTile {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 40
                                height: 40
                                radius: 20
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                LoadingSkeletonTile { width: 180; height: 14 }
                                LoadingSkeletonTile { width: 120; height: 10 }
                            }
                        }
                    }
                }
            }
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            anchors.fill: parent

            Switch {
                id: visibleSwitch
                text: "Visible (shimmer only runs while visible)"
                checked: true
            }
            Item { Layout.fillHeight: true }
        }
    }
}

// category: Skeletons
