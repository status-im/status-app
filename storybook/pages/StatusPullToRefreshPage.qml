import QtQuick
import QtQuick.Controls

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme

import Storybook

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs { id: logs }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Rectangle {
            anchors.centerIn: parent
            width: 360
            height: 480
            color: Theme.palette.statusAppLayout.backgroundColor
            border.color: Theme.palette.baseColor2

            StatusListView {
                id: listView
                objectName: "listView"

                anchors.fill: parent
                anchors.margins: 1
                model: ctrlRows.value

                header: StatusBaseText {
                    width: ListView.view.width
                    padding: Theme.padding
                    text: "Header that scrolls with the list"
                    font.weight: Font.Bold
                }

                delegate: StatusBaseText {
                    required property int index

                    width: ListView.view.width
                    padding: Theme.padding
                    text: "Row " + index
                }

                StatusPullToRefresh {
                    objectName: "pullToRefresh"
                    flickable: listView
                    enabled: ctrlEnabled.checked
                    refreshing: ctrlRefreshing.checked

                    onRefreshRequested: {
                        logs.logEvent("StatusPullToRefresh::refreshRequested")
                        if (ctrlAutoRefresh.checked) {
                            ctrlRefreshing.checked = true
                            refreshTimer.restart()
                        }
                    }
                }
            }
        }

        Timer {
            id: refreshTimer
            interval: 2000
            onTriggered: ctrlRefreshing.checked = false
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        Column {
            Switch {
                id: ctrlEnabled
                objectName: "ctrlEnabled"
                text: "Enabled"
                checked: true
            }

            Switch {
                id: ctrlRefreshing
                objectName: "ctrlRefreshing"
                text: "Refreshing"
            }

            Switch {
                id: ctrlAutoRefresh
                objectName: "ctrlAutoRefresh"
                text: "A pull refreshes for 2 seconds"
                checked: true
            }

            Row {
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Rows:"
                }

                Slider {
                    id: ctrlRows
                    from: 0
                    to: 50
                    stepSize: 1
                    value: 30
                }
            }
        }
    }
}

// category: Components
// status: good
