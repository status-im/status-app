import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import StatusQ.Core.Theme

import mainui

SplitView {
    id: root

    Logs { id: logs }

    readonly property var sampleImages: [
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC",
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNg+M8AAAICAQB7CYF4AAAAAElFTkSuQmCC",
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYPgPAAEDAQAIicLsAAAAAElFTkSuQmCC"
    ]

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 800
            color: Theme.palette.baseColor4
            border.color: Theme.palette.baseColor2

            ShareComposer {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: ctrlText.text
                imagePaths: root.sampleImages.slice(0, ctrlImages.value)
                sendEnabled: ctrlSendEnabled.checked
                onSendRequested: (text, imagePaths) =>
                    logs.logEvent("sendRequested: " + text + " / " + imagePaths.length + " image(s)")
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 320

        logsView.logText: logs.logText

        ColumnLayout {
            TextField { id: ctrlText; Layout.fillWidth: true; text: "https://youtu.be/d3wHC956WLk" }
            RowLayout {
                Label { text: "images" }
                SpinBox { id: ctrlImages; from: 0; to: 3 }
            }
            CheckBox { id: ctrlSendEnabled; text: "send enabled (selection non-empty)"; checked: true }
        }
    }
}

// category: Panels
