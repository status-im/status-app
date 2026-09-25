import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import mainui

SplitView {
    id: root

    Logs { id: logs }

    // Self-contained 1x1 PNG so the page works in isolation, standing in for
    // the cached file paths the share intake delivers.
    readonly property string sampleImage:
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        SharePreviewPanel {
            anchors.centerIn: parent
            width: 400
            height: 500

            destinationName: destinationNameField.text
            text: "Look at this https://example.com/article"
            imagePaths: {
                const paths = []
                for (let i = 0; i < imageCountSpinBox.value; i++)
                    paths.push(root.sampleImage)
                return paths
            }

            onSendRequested: (text) => logs.logEvent("SharePreviewPanel::sendRequested: " + text)
            onBackRequested: logs.logEvent("SharePreviewPanel::backRequested")
            onCancelRequested: logs.logEvent("SharePreviewPanel::cancelRequested")
        }
    }

    LogsAndControlsPanel {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 320

        logsView.logText: logs.logText

        ColumnLayout {
            Label {
                text: "Destination name"
            }
            TextField {
                id: destinationNameField
                text: "Design crew"
            }
            Label {
                text: "Shared images"
            }
            SpinBox {
                id: imageCountSpinBox
                from: 0
                to: 10
                value: 2
            }
        }
    }
}
