import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Components
import StatusQ.Core.Theme

SplitView {
    id: root

    Timer {
        interval: 1000
        repeat: true
        running: autoCountdownSwitch.checked && runningSwitch.checked && secondsLeftControl.value > 0
        onTriggered: secondsLeftControl.value = Math.max(0, secondsLeftControl.value - 1)
    }

    Rectangle {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        color: Theme.palette.baseColor4

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Theme.padding

            CountdownProgressIndicator {
                id: indicator

                Layout.alignment: Qt.AlignHCenter
                indicatorSize: indicatorSizeControl.value
                strokeWidth: strokeWidthControl.value
                timeoutSeconds: timeoutControl.value
                secondsLeft: secondsLeftControl.value
                running: runningSwitch.checked
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "%1 seconds remaining".arg(secondsLeftControl.value)
            }
        }
    }

    Rectangle {
        SplitView.preferredWidth: 360
        SplitView.fillHeight: true

        color: Theme.palette.baseColor3

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.padding
            spacing: Theme.padding

            Label {
                text: "CountdownProgressIndicator"
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "Timeout (seconds):"
                }

                SpinBox {
                    id: timeoutControl

                    Layout.fillWidth: true
                    from: 1
                    to: 600
                    value: 60
                    editable: true
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "Seconds left:"
                }

                SpinBox {
                    id: secondsLeftControl

                    Layout.fillWidth: true
                    from: 0
                    to: timeoutControl.value
                    value: 45
                    editable: true
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "Indicator size:"
                }

                SpinBox {
                    id: indicatorSizeControl

                    Layout.fillWidth: true
                    from: 24
                    to: 160
                    value: 72
                    editable: true
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Label {
                    text: "Stroke width:"
                }

                SpinBox {
                    id: strokeWidthControl

                    Layout.fillWidth: true
                    from: 1
                    to: 12
                    value: 4
                    editable: true
                }
            }

            Switch {
                id: runningSwitch

                text: "Running"
                checked: true
            }

            Switch {
                id: autoCountdownSwitch

                text: "Auto countdown"
                checked: true
            }

            Button {
                Layout.fillWidth: true
                text: "Reset countdown"
                onClicked: secondsLeftControl.value = timeoutControl.value
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}

// category: Components
// status: good
