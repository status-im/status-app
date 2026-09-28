import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import StatusQ.Core.Theme

import mainui

SplitView {
    id: root

    Logs { id: logs }

    Pane {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 800
            color: Theme.palette.statusListItem.backgroundColor
            border.color: Theme.palette.baseColor2

            ShareDestinationTabBar {
                id: tabBar
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Theme.halfPadding
                position: ctrlPosition.value
                onCurrentIndexChanged: logs.logEvent("currentIndex: " + currentIndex)
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.fillHeight: true
        SplitView.preferredWidth: 320

        logsView.logText: logs.logText

        ColumnLayout {
            RowLayout {
                Label { text: "position" }
                Slider { id: ctrlPosition; from: 0; to: 3; stepSize: 0.05 }
            }
            ComboBox {
                model: ["All", "Contacts", "Groups", "Communities"]
                onActivated: index => {
                    tabBar.currentIndex = index
                    ctrlPosition.value = index
                }
            }
        }
    }
}

// category: Panels
