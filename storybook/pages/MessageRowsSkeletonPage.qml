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

                MessageRowsSkeleton {
                    anchors.fill: parent
                    anchors.margins: Theme.padding
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
                from: 300
                to: 1000
                value: 700
                stepSize: 1
            }
            Item { Layout.fillHeight: true }
        }
    }
}

// category: Skeletons
