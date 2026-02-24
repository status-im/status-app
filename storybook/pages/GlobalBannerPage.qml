import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ

import Storybook

import utils
import mainui

SplitView {
    Logs { id: logs }

    orientation: Qt.Vertical
    SplitView.fillWidth: true

    QtObject {
        id: d
        property bool userDeclinedBackupBanner
        property bool testnetEnabled

        readonly property var networkChecker: NetworkChecker {
            active: ctrlUseOnlineChecker.checked
        }
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        ColumnLayout {
            width: ctrlWidth.value
            anchors.centerIn: parent

            Label {
                text: "Online > Testnet > Seedphrase"
            }
            Label {
                text: "Width: %1; visible: %2".arg(parent.width).arg(banner.visible ? "true" : "false")
            }

            GlobalBanner {
                id: banner
                Tracer { border.color: "blue" }

                Layout.fillWidth: true
                isOnline: ctrlIsOnline.checked
                testnetEnabled: d.testnetEnabled
                seedphraseBackedUp: d.userDeclinedBackupBanner

                onOpenTestnetPopupRequested: {
                    logs.logEvent("onOpenTestnetPopupRequested")
                    d.testnetEnabled = false
                }
                onOpenBackUpSeedPopupRequested: {
                    logs.logEvent("onOpenBackUpSeedPopupRequested")
                }
                onUserDeclinedBackupBannerRequested: {
                    logs.logEvent("onUserDeclinedBackupBannerRequested")
                    d.userDeclinedBackupBanner = true
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 150
        SplitView.preferredHeight: 150

        logsView.logText: logs.logText

        RowLayout {
            Switch {
                id: ctrlUseOnlineChecker
                text: "Use real online checker"
                checked: false
            }

            Switch {
                id: ctrlIsOnline
                text: "Online"
                checked: true
                enabled: !ctrlUseOnlineChecker.checked

                Binding on checked {
                    when: ctrlUseOnlineChecker.checked
                    value: d.networkChecker.isOnline
                }
            }

            Switch {
                id: ctrlTestnetEnabled
                text: "Testnet"
                checked: d.testnetEnabled
                onToggled: d.testnetEnabled = checked
            }

            Switch {
                id: ctrlUserDeclinedBackupBanner
                text: "Seedphrase backed up"
                checked: d.userDeclinedBackupBanner
                onToggled: d.userDeclinedBackupBanner = checked
            }

            ToolSeparator {}

            Label { text: "Width:" }
            Slider {
                id: ctrlWidth
                from: 100
                to: 1000
                value: 600
            }
        }
    }
}

// category: Components
// status: good
