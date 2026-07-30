import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Profile.views

import Storybook

SplitView {
    id: root

    orientation: Qt.Vertical

    Logs {
        id: logs
    }

    QtObject {
        id: d

        property int peerCount: 16
        property bool peerCountLoading: false
        property string peerCountError: ""
    }

    Timer {
        id: refreshTimer

        interval: 1200
        onTriggered: {
            d.peerCountLoading = false
            d.peerCount = peerCountSpinBox.value
        }
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        LogosNetworkView {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 596)

            contentWidth: width
            sectionTitle: "Logos Network"

            peerCount: d.peerCount
            peerCountLoading: d.peerCountLoading
            peerCountError: d.peerCountError
            pollingActive: pollingSwitch.checked

            onRefreshPeerCountRequested: {
                logs.logEvent("LogosNetworkView::refreshPeerCountRequested")
                d.peerCountLoading = true
                refreshTimer.restart()
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 230

        logsView.logText: logs.logText

        ColumnLayout {
            RowLayout {
                spacing: 10

                SpinBox {
                    id: peerCountSpinBox

                    from: -1
                    to: 999
                    value: 16
                    textFromValue: value => value < 0 ? "Unknown" : value.toString()
                    valueFromText: text => text === "Unknown" ? -1 : Number(text)
                    onValueModified: d.peerCount = value
                }

                Text {
                    text: "Peer count"
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            Switch {
                id: loadingSwitch

                text: "Loading"
                checked: d.peerCountLoading
                onToggled: d.peerCountLoading = checked
            }

            Switch {
                id: pollingSwitch

                text: "Polling active"
                checked: true
            }

            CheckBox {
                id: errorCheckBox

                text: "Show error"
                onToggled: d.peerCountError = checked ? "ERR_CONNECTION_FAILED" : ""
            }
        }
    }
}

// category: Settings
// status: good
