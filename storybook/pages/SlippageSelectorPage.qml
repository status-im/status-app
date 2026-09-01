import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

import shared.controls
import utils

import Storybook

SplitView {
    orientation: Qt.Horizontal

    Logs { id: logs }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        SlippageSelector {
            id: slippageSelector
            anchors.centerIn: parent
            width: 440

            onEdited: newValue => {
                logs.logEvent("edited", ["newValue"], arguments)
                value = newValue
            }
            onCommitted: logs.logEvent("committed")
        }
    }

    LogsAndControlsPanel {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 300

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent

            Label {
                Layout.fillWidth: true
                font.weight: Font.Medium
                text: "Value: %1".arg(slippageSelector.value)
            }
            Label {
                Layout.fillWidth: true
                font.weight: Font.Medium
                text: "Valid: %1".arg(slippageSelector.valid ? "true" : "false")
            }

            ColumnLayout {
                Repeater {
                    model: [0.1, 0.5, 0.24, 0.8, 2]

                    Button {
                        text: "set " + modelData
                        onClicked: slippageSelector.value = modelData
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}

// category: Controls

// https://www.figma.com/design/TS0eQX9dAZXqZtELiwKIoK/Swap---Milestone-1?node-id=3409-257346&t=ENK93cK7GyTqEV8S-0
// https://www.figma.com/design/TS0eQX9dAZXqZtELiwKIoK/Swap---Milestone-1?node-id=3410-262441&t=ENK93cK7GyTqEV8S-0
