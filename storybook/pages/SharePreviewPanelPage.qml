import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import Storybook

import mainui

SplitView {
    id: root

    Logs { id: logs }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        SharePreviewPanel {
            anchors.centerIn: parent
            width: 400
            height: 500

            destinationName: destinationNameField.text
            text: "Look at this https://example.com/article"

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
        }
    }
}
