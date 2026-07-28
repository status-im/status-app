import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import utils

import mainui

SplitView {
    id: root

    Logs { id: logs }

    // Self-contained 1x1 PNGs so the page works in isolation, standing in for
    // the cached file paths the share intake delivers. Distinct pixels because
    // the chat input deduplicates identical entries.
    readonly property var sampleImages: [
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC",
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNg+M8AAAICAQB7CYF4AAAAAElFTkSuQmCC",
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNgYPgPAAEDAQAIicLsAAAAAElFTkSuQmCC"
    ]

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        SharePreviewPanel {
            id: previewPanel

            anchors.centerIn: parent
            width: 400
            height: 500

            destinationName: destinationNameField.text
            destinationColor: destinationColorField.text
            destinationEmoji: destinationEmojiField.text
            destinationChatType: communityChannelCheckBox.checked
                                 ? Constants.chatType.communityChat
                                 : Constants.chatType.oneToOne
            destinationSectionName: destinationSectionNameField.text
            text: "Look at this https://example.com/article"
            imagePaths: root.sampleImages.slice(0, imageCountSpinBox.value)

            onSendRequested: (text, imagePaths) => logs.logEvent(
                "SharePreviewPanel::sendRequested",
                ["text", "imagePaths"], [text, JSON.stringify(imagePaths)])
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
                text: "Destination color"
            }
            TextField {
                id: destinationColorField
                text: "#7CDA00"
            }
            Label {
                text: "Destination emoji"
            }
            TextField {
                id: destinationEmojiField
                text: ""
            }
            CheckBox {
                id: communityChannelCheckBox
                text: "Community channel"
                checked: true
            }
            Label {
                text: "Section name"
            }
            TextField {
                id: destinationSectionNameField
                text: "Design DAO"
            }
            Label {
                text: "Shared images"
            }
            SpinBox {
                id: imageCountSpinBox
                from: 0
                to: root.sampleImages.length
                value: 2
            }
            Button {
                text: "Reset shared payload"
                onClicked: previewPanel.reset()
            }
        }
    }
}
