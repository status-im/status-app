import QtQuick
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

// Loading placeholder mimicking the wallet token list (TokenDelegate rows):
// icon and token name with balance below on the left, currency value with
// change indicators right-aligned on the right
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

        Repeater {
            model: 8
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                spacing: Theme.padding

                LoadingSkeletonTile {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: width / 2
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    LoadingSkeletonTile {
                        implicitWidth: 90
                        implicitHeight: 15
                    }
                    LoadingSkeletonTile {
                        implicitWidth: 130
                        implicitHeight: 12
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                ColumnLayout {
                    spacing: 6

                    LoadingSkeletonTile {
                        Layout.alignment: Qt.AlignRight
                        implicitWidth: 100
                        implicitHeight: 15
                    }
                    LoadingSkeletonTile {
                        Layout.alignment: Qt.AlignRight
                        implicitWidth: 130
                        implicitHeight: 12
                    }
                }
            }
        }
    }
}
