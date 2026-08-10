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

            // toolbar-like strip, as hosted by the section chrome
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 40
                width: widthSlider.value
                height: 56
                color: Theme.palette.baseColor4
                border.color: Theme.palette.baseColor2

                ChatHeaderSkeleton {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.padding
                }
            }
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            anchors.fill: parent

            Label { text: "Toolbar width: %1".arg(widthSlider.value) }
            Slider {
                id: widthSlider
                Layout.fillWidth: true
                from: 200
                to: 900
                value: 600
                stepSize: 1
            }
            Item { Layout.fillHeight: true }
        }
    }
}

// category: Skeletons
