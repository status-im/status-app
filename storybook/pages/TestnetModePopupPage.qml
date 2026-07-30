import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components

import Storybook

import shared.popups
import utils

SplitView {
    id: root

    Logs { id: logs }

    property bool areTestNetworksEnabled: false

    Connections {
        target: Global
        function onDisplayToastMessage(title, subTitle, icon, loading, ephNotifType, url) {
            logs.logEvent("Global.displayToastMessage",
                          ["title", "icon", "ephNotifType"],
                          [title, icon, ephNotifType])
            toast.primaryText = title
            toast.secondaryText = subTitle
            toast.icon.name = icon
            toast.loading = loading
            toast.type = ephNotifType
            toast.linkUrl = url
            toast.open = true
        }
    }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Item {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            PopupBackground {
                anchors.fill: parent
            }

            TestnetModePopup {
                id: dialog
                anchors.centerIn: parent
                modal: false
                visible: true
                closePolicy: Popup.NoAutoClose
                destroyOnClose: false
                areTestNetworksEnabled: root.areTestNetworksEnabled
                onToggleTestnetRequested: (enabled) => {
                    root.areTestNetworksEnabled = enabled
                    logs.logEvent("toggleTestnetRequested", ["enabled"], [enabled])
                }
            }

            StatusToastMessage {
                id: toast
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                open: false
                duration: 4000
                onClose: open = false
            }
        }

        LogsAndControlsPanel {
            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 150
            logsView.logText: logs.logText
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            CheckBox {
                text: "Testnet mode enabled"
                checked: root.areTestNetworksEnabled
                onToggled: root.areTestNetworksEnabled = checked
            }

            Button {
                text: "Reopen"
                onClicked: dialog.open()
            }

            Item { Layout.fillHeight: true }
        }
    }
}

// category: Popups
