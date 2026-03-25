import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import StatusQ.Core.Theme

import shared.controls

import Storybook

SplitView {
    orientation: Qt.Horizontal

    Logs { id: logs }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        background: Rectangle {
            color: Theme.palette.baseColor4
        }

        ErrorTag {
            width: ctrlWidth.value || implicitWidth
            anchors.centerIn: parent
            text: ctrlText.text
            buttonText: ctrlButtonText.text
            buttonVisible: buttonVisible.checked
            asset.name: ctrlAssetName.text
            loading: ctrlLoading.checked
            onButtonClicked: logs.logEvent("ErrorTag::onButtonClicked")
        }
    }

    LogsAndControlsPanel {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 300

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent

            RowLayout {
                Layout.fillWidth: true
                Label { text: "Text:" }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlText
                    text: "Not enough ETH to pay gas fees"
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Button text:" }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlButtonText
                    text: "Add ETH"
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Asset name:" }
                TextField {
                    Layout.fillWidth: true
                    id: ctrlAssetName
                    text: "warning"
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: "Width:" }
                SpinBox {
                    id: ctrlWidth
                    from: 0
                    to: 400
                    value: 0 // 0 == implicitWidth
                    stepSize: 20
                    textFromValue: function(value, locale) { return value === 0 ? "Implicit" : value }
                }
            }
            Switch {
                id: ctrlLoading
                text: "Loading"
            }
            Switch {
                id: buttonVisible
                text: "Button Visible"
            }
            Item { Layout.fillHeight: true }
        }
    }
}

// category: Controls
// status: good
// https://www.figma.com/design/TS0eQX9dAZXqZtELiwKIoK/Swap---Milestone-1?node-id=3413-311788&t=D3qGKqNjDBuLEEaD-0
