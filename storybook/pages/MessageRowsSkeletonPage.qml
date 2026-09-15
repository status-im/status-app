import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Chat.panels

import StatusQ.Core.Theme

import Storybook

SplitView {
    id: root

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Theme.style: darkThemeSwitch.checked ? Theme.Style.Dark : Theme.Style.Light

        Rectangle {
            anchors.centerIn: parent
            width: widthSlider.value
            height: parent.height - 40
            color: Theme.palette.baseColor4
            border.color: Theme.palette.baseColor2
            clip: true

            // Bottom-anchored like the paging placeholder: shrinking the
            // height via the slider must keep the pattern at the bottom
            // seam pinned while the top edge moves.
            MessageRowsSkeleton {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    margins: Theme.padding
                }
                height: heightSlider.value
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
            Label { text: "Skeleton height: %1".arg(heightSlider.value) }
            Slider {
                id: heightSlider
                Layout.fillWidth: true
                from: 200
                to: 100000
                value: 12000
                stepSize: 50
            }
            Switch {
                id: darkThemeSwitch
                text: "Dark theme"
            }
            Item { Layout.fillHeight: true }
        }
    }
}

// category: Skeletons
