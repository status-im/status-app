import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core
import AppLayouts.Chat

import Storybook

SplitView {
    orientation: Qt.Vertical

    Logs { id: logs }

    ChatLayoutLoading {
        id: sectionLoading
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        showMembersPanel: ctrlShowMembersPanel.checked
    }

    LogsAndControlsPanel {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 300

        logsView.logText: logs.logText

        ColumnLayout {
            anchors.fill: parent

            Switch {
                id: ctrlShowMembersPanel
                text: "Show Members Panel"
            }
            Item { Layout.fillHeight: true }
        }
    }
}

// category: Layouts