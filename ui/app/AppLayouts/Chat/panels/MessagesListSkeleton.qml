import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking the messages chat list: header with action
// buttons, then chat rows (avatar, name, message preview, timestamp)
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
        spacing: Theme.padding

        // header: title + search/new-chat buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Theme.halfPadding
            spacing: Theme.halfPadding

            LoadingSkeletonTile {
                implicitWidth: 90
                implicitHeight: 18
            }
            Item { Layout.fillWidth: true }
            LoadingSkeletonTile {
                implicitWidth: 32
                implicitHeight: 32
                radius: width / 2
            }
            LoadingSkeletonTile {
                implicitWidth: 32
                implicitHeight: 32
                radius: width / 2
            }
        }

        // chat rows
        Repeater {
            model: 9
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
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
                        implicitWidth: 180
                        implicitHeight: 12
                    }
                }
                LoadingSkeletonTile {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 36
                    implicitHeight: 10
                }
            }
        }
    }
}
