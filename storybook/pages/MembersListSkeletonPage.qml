import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Chat.panels

import StatusQ.Core.Theme

import Storybook

SplitView {
    id: root

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Item {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            Rectangle {
                anchors.centerIn: parent
                width: widthSlider.value
                height: parent.height - 40
                color: Theme.palette.baseColor4
                border.color: Theme.palette.baseColor2

                MembersListSkeleton {
                    anchors.fill: parent
                }
            }
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            anchors.fill: parent

            Label { text: "Panel width: %1".arg(widthSlider.value) }
            Slider {
                id: widthSlider
                Layout.fillWidth: true
                from: 80
                to: 400
                value: 270
                stepSize: 1
            }
            Item { Layout.fillHeight: true }
        }
    }
}

// category: Skeletons
