import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import mainui

SplitView {
    Logs { id: logs }

    SplitView {
        SplitView.fillHeight: true
        SplitView.fillWidth: true
        orientation: Qt.Vertical

        SessionTransitionView {
            SplitView.fillHeight: true
            SplitView.fillWidth: true

            phase: phaseCombo.currentIndex
            isMobile: ctrlMobile.checked

            onRetryRequested: logs.logEvent("retryRequested")
            onQuitRequested: logs.logEvent("quitRequested")
        }

        LogsView {
            SplitView.preferredHeight: 150
            logText: logs.logText
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            Label {
                text: "Phase"
            }
            ComboBox {
                id: phaseCombo
                model: ["Active", "Ending", "DrainTimeout", "LogoutTimeout", "LogoutFailed", "StartFailed"]
                currentIndex: 1
            }
            Switch {
                id: ctrlMobile
                text: "Mobile"
            }
        }
    }
}

// category: Views
// status: good
