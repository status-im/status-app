import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Components

import shared.popups

SplitView {
    id: root

    orientation: Qt.Horizontal

    Logs { id: logs }

    // Helper timers for test scenarios
    Timer {
        id: timer1
        interval: 1500
        onTriggered: {
            if (root.currentScenario === "success") {
                logs.logEvent("Changing to reading state")
                stateCombo.currentIndex = 2 // reading
                timer2.start()
            } else if (root.currentScenario === "error") {
                logs.logEvent("Changing to reading state")
                stateCombo.currentIndex = 2 // reading
                timer2.start()
            } else if (root.currentScenario === "quick") {
                logs.logEvent("Quick change to reading")
                stateCombo.currentIndex = 2 // reading
                timer2.start()
            }
        }
    }

    Timer {
        id: timer2
        interval: root.currentScenario === "quick" ? 300 : 1500
        onTriggered: {
            if (root.currentScenario === "success") {
                logs.logEvent("Changing to idle state (success)")
                stateCombo.currentIndex = 0 // idle (will trigger success)
            } else if (root.currentScenario === "error") {
                logs.logEvent("Changing to error state")
                stateCombo.currentIndex = 3 // error
            } else if (root.currentScenario === "quick") {
                logs.logEvent("Quick change to idle (success)")
                stateCombo.currentIndex = 0 // idle
            }
            root.currentScenario = ""
        }
    }

    property string currentScenario: ""

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        KeycardChannelDrawer {
            id: drawer

            currentState: stateCombo.currentValue
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

            onDismissed: {
                logs.logEvent("KeycardChannelDrawer::dismissed()")
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.preferredWidth: 350
        SplitView.fillHeight: true

        logsView.logText: logs.logText

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.padding

            // State control section
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.halfPadding

                Label {
                    Layout.preferredWidth: 120
                    text: "Current state:"
                }

                ComboBox {
                    id: stateCombo
                    Layout.fillWidth: true
                    
                    textRole: "text"
                    valueRole: "value"
                    
                    model: ListModel {
                        ListElement { text: "Idle"; value: "idle" }
                        ListElement { text: "Waiting for Keycard"; value: "waiting-for-keycard" }
                        ListElement { text: "Reading"; value: "reading" }
                        ListElement { text: "Error"; value: "error" }
                    }
                    
                    currentIndex: 0
                }
            }

            // State info display
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: infoColumn.implicitHeight + Theme.padding * 2
                color: Theme.palette.baseColor5
                radius: Theme.radius
                border.width: 1
                border.color: Theme.palette.baseColor2

                ColumnLayout {
                    id: infoColumn
                    anchors.fill: parent
                    anchors.margins: Theme.padding
                    spacing: Theme.halfPadding

                    StatusBaseText {
                        Layout.fillWidth: true
                        text: "State Information"
                        font.bold: true
                        font.pixelSize: Theme.primaryTextFontSize
                    }

                    StatusBaseText {
                        Layout.fillWidth: true
                        text: "Current: %1".arg(stateCombo.currentText)
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.baseColor1
                    }

                    StatusBaseText {
                        Layout.fillWidth: true
                        text: "Opened: %1".arg(drawer.opened ? "Yes" : "No")
                        font.pixelSize: Theme.tertiaryTextFontSize
                        color: Theme.palette.baseColor1
                    }
                }
            }

            // Scenario buttons section
            Label {
                Layout.fillWidth: true
                Layout.topMargin: Theme.padding
                text: "Test Scenarios:"
                font.bold: true
            }

            Button {
                Layout.fillWidth: true
                text: "Simulate Success Flow"
                onClicked: {
                    logs.logEvent("Starting success flow simulation")
                    root.currentScenario = "success"
                    stateCombo.currentIndex = 1 // waiting-for-keycard
                    timer1.start()
                }
            }

            Button {
                Layout.fillWidth: true
                text: "Simulate Error Flow"
                onClicked: {
                    logs.logEvent("Starting error flow simulation")
                    root.currentScenario = "error"
                    stateCombo.currentIndex = 1 // waiting-for-keycard
                    timer1.start()
                }
            }

            Button {
                Layout.fillWidth: true
                text: "Simulate Quick State Changes"
                onClicked: {
                    logs.logEvent("Testing state queue with rapid changes")
                    root.currentScenario = "quick"
                    stateCombo.currentIndex = 1 // waiting-for-keycard
                    timer1.interval = 300
                    timer1.start()
                }
            }

            Button {
                Layout.fillWidth: true
                text: "Open Drawer Manually"
                onClicked: {
                    logs.logEvent("Manually opening drawer")
                    drawer.open()
                }
            }

            Button {
                Layout.fillWidth: true
                text: "Clear Logs"
                onClicked: logs.clear()
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}

// category: Popups
// status: good

