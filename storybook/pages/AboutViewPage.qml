import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core as SQCore
import AppLayouts.Profile.views

import Storybook

import utils

SplitView {
    Logs { id: logs }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        AboutView {
            SplitView.fillWidth: true
            SplitView.fillHeight: true
            contentWidth: parent.width

            isProduction: ctrlProduction.checked
            currentVersion: isProduction ? "0.13.2" : "0.13.2-dev"
            gitCommit: "92b88e8a3e1d48f2c39d1db6e4d577ebbe21f7a9"
            statusGoVersion: "v0.162.9"
            qtRuntimeVersion: SQCore.SystemUtils.qtRuntimeVersion()

            onCheckForUpdates: logs.logEvent("store::checkForUpdates")
            onOpenLink: (url) => Qt.openUrlExternally(url)
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 200

            logsView.logText: logs.logText

            ColumnLayout {
                anchors.fill: parent

                Switch {
                    id: ctrlProduction
                    text: "Production"
                    checked: true
                }
            }
        }
    }
}

// category: Settings
// status: good
// https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?node-id=1159%3A114479
// https://www.figma.com/file/idUoxN7OIW2Jpp3PMJ1Rl8/%E2%9A%99%EF%B8%8F-Settings-%7C-Desktop?node-id=1684%3A127762
