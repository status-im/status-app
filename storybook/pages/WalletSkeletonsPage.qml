import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import AppLayouts.Wallet.panels

import Storybook

SplitView {
    id: root

    orientation: Qt.Vertical

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: ctrlWidth.value
            height: parent.height - 2 * Theme.padding
            color: Theme.palette.statusAppLayout.backgroundColor
            border.color: Theme.palette.baseColor2

            StackLayout {
                anchors.fill: parent
                anchors.margins: Theme.padding
                currentIndex: ctrlCenter.checked ? 0 : 1

                WalletCenterPanelSkeleton {}

                WalletAccountsSkeleton {}
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 120
        SplitView.preferredHeight: 120
        SplitView.fillWidth: true

        RowLayout {
            anchors.fill: parent
            spacing: Theme.bigPadding

            ColumnLayout {
                RadioButton {
                    id: ctrlCenter
                    text: "Center panel"
                    checked: true
                }
                RadioButton {
                    text: "Accounts (left) panel"
                }
            }

            RowLayout {
                Label { text: "Width:" }
                Slider {
                    id: ctrlWidth
                    from: 320
                    to: 900
                    value: 455
                }
                Label { text: Math.round(ctrlWidth.value) }
            }

            Item { Layout.fillWidth: true }
        }
    }
}

// category: Skeletons
