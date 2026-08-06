import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking an open chat: message bubbles and the input bar
LoadingSkeletonGroup {
    id: root

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.padding

        Item { Layout.fillHeight: true }

        Repeater {
            model: 5
            RowLayout {
                readonly property bool own: index % 2 === 1

                required property int index

                Layout.fillWidth: true
                spacing: Theme.halfPadding

                LoadingSkeletonTile {
                    visible: !parent.own
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: width / 2
                }
                Item {
                    visible: parent.own
                    Layout.fillWidth: true
                }
                LoadingSkeletonTile {
                    implicitWidth: 180 + (parent.index % 3) * 40
                    implicitHeight: 44 + (parent.index % 2) * 16
                    radius: Theme.radius
                }
                Item {
                    visible: !parent.own
                    Layout.fillWidth: true
                }
            }
        }

        // input bar
        LoadingSkeletonTile {
            Layout.fillWidth: true
            Layout.topMargin: Theme.padding
            implicitHeight: 40
            radius: 20
        }
    }
}
