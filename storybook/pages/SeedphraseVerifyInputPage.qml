import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Onboarding.components
import Storybook
import shared

SplitView {
    id: root

    orientation: Qt.Horizontal

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        SeedphraseVerifyInput {
            id: input
            anchors.centerIn: parent
            width: 300
            valid: text.trim().toLowerCase() === "abandon"
            seedSuggestions: BIP39_en {}
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 280
        SplitView.preferredWidth: 320
        SplitView.fillHeight: true

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "text: %1".arg(input.text)
            }
            Label {
                text: "valid: %1".arg(input.valid)
            }
        }
    }
}

// category: Onboarding
