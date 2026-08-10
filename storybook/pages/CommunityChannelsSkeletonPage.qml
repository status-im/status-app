import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Communities.panels

import StatusQ.Core.Theme

import Models
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

                CommunityChannelsSkeleton {
                    anchors.fill: parent

                    name: nameField.text
                    membersCount: 245
                    image: ModelsData.icons.status
                    color: "#4360DF"
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
            Label { text: "Community name" }
            TextField {
                id: nameField
                Layout.fillWidth: true
                text: "Status Community"
            }
            Item { Layout.fillHeight: true }
        }
    }
}

// category: Skeletons
