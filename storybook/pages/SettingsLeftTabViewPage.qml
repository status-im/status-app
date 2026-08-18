import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ

import Models
import Storybook

import AppLayouts.Profile.views
import AppLayouts.Profile.helpers

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    SettingsLeftTabView {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        model: SettingsEntriesModel {
            isKeycardEnabled: ctrlIsKeycardEnabled.checked
            showWalletEntries: ctrlShowWalletEntries.checked
            showBackUpSeed: ctrlShowBackUpSeed.checked
            syncingBadgeCount: ctrlSyncingBadgeCount.value
            messagingBadgeCount: ctrlMessagingBadgeCount.value
            localBackupEnabled: ctrlLocalBackupEnabled.checked
        }
        onMenuItemClicked: function(subsection) {
            settingsSubsection = subsection
            logs.logEvent("onMenuItemClicked", ["subsection"], [subsection])
        }

    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 100
        SplitView.fillWidth: true

        logsView.logText: logs.logText

        RowLayout {
            spacing: 20
            Layout.fillHeight: true

            RowLayout {
                Label { text: "Syncing badge count:" }
                SpinBox {
                    id: ctrlSyncingBadgeCount
                    value: 1
                    from: 0
                    to: 999
                }
            }
            RowLayout {
                Label { text: "Messaging badge count:" }
                SpinBox {
                    id: ctrlMessagingBadgeCount
                    value: 2
                    from: 0
                    to: 999
                }
            }
            Switch {
                id: ctrlShowBackUpSeed
                checked: true
                text: "Show backup seed"
            }
            Switch {
                id: ctrlShowWalletEntries
                checked: true
                text: "Show wallet entries"
            }
            Switch {
                id: ctrlIsKeycardEnabled
                checked: true
                text: "Is keycard enabled"
            }
            Switch {
                id: ctrlLocalBackupEnabled
                checked: true
                text: "Local (on-device) backup enabled"
            }
        }
    }
}

// category: Views
// status: good
