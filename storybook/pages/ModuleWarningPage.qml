import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Theme

import Storybook

import shared.panels

SplitView {
    id: root

    Logs { id: logs }

    orientation: Qt.Vertical
    SplitView.fillWidth: true

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        ColumnLayout {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: ctrlWidth.value

            spacing: 0

            ModuleWarningStack {
                id: stack

                Layout.fillWidth: true

                ModuleWarning {
                    id: setPasswordWarning

                    objectName: "setPasswordWarning"
                    Layout.fillWidth: true

                    delay: false
                    active: true
                    collapsible: true
                    type: ModuleWarning.Warning
                    progressValue: ctrlProgress.value

                    actions: RowLayout {
                        spacing: Theme.halfPadding

                        ModuleWarningButton {
                            text: "Set password"
                            onClicked: logs.logEvent("Set password clicked")
                        }
                        Label {
                            text: "or"
                            color: Theme.palette.indirectColor1
                        }
                        ModuleWarningButton {
                            text: "Create / Log in"
                            onClicked: logs.logEvent("Create / Log in clicked")
                        }
                    }

                    onCollapsedChanged: logs.logEvent("setPasswordWarning collapsed: " + collapsed)
                    onActiveChanged: logs.logEvent("setPasswordWarning active: " + active)
                    onCloseClicked: logs.logEvent("setPasswordWarning closeClicked")
                }

                ModuleWarning {
                    id: secondCollapsibleWarning

                    objectName: "secondCollapsibleWarning"
                    Layout.fillWidth: true

                    delay: false
                    active: ctrlExtraCollapsible.checked
                    collapsible: true
                    type: ModuleWarning.Danger
                    text: "Second collapsible warning"

                    onCollapsedChanged: logs.logEvent("secondCollapsibleWarning collapsed: " + collapsed)
                }

                ModuleWarning {
                    id: thirdCollapsibleWarning

                    objectName: "thirdCollapsibleWarning"
                    Layout.fillWidth: true

                    delay: false
                    active: ctrlExtraCollapsible.checked
                    collapsible: true
                    type: ModuleWarning.Success
                    collapsedIconName: "info"
                    text: "Third collapsible warning, custom collapsed icon"

                    onCollapsedChanged: logs.logEvent("thirdCollapsibleWarning collapsed: " + collapsed)
                }

                ModuleWarning {
                    id: dismissibleWarning

                    objectName: "dismissibleWarning"
                    Layout.fillWidth: true

                    delay: false
                    active: true
                    type: ModuleWarning.Success
                    text: "Dismissible warning, its close button hides it"
                    buttonText: "Action"

                    onClicked: logs.logEvent("dismissibleWarning clicked")
                    onCloseClicked: {
                        logs.logEvent("dismissibleWarning closeClicked")
                        hide()
                    }
                }

                ModuleWarning {
                    id: noCloseWarning

                    objectName: "noCloseWarning"
                    Layout.fillWidth: true

                    delay: false
                    active: true
                    closeBtnVisible: false
                    type: ModuleWarning.Danger
                    text: "Warning without a close button"
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                columns: 5
                rowSpacing: 0
                columnSpacing: 0

                Repeater {
                    model: 25

                    Button {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        text: "Content %1".arg(index)
                        onClicked: logs.logEvent("Content %1 clicked".arg(index))
                    }
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 200
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            RowLayout {
                Label { text: "Set password:" }
                Button {
                    text: "Activate"
                    onClicked: setPasswordWarning.show()
                }
                Button {
                    text: "Show for 5 s"
                    onClicked: setPasswordWarning.showFor(5000)
                }
                Label { text: "Progress:" }
                Slider {
                    id: ctrlProgress
                    from: -1
                    to: 100
                    stepSize: 1
                    value: -1
                }
                Switch {
                    id: ctrlExtraCollapsible
                    text: "Second and third collapsible"
                    checked: true
                }
                Button {
                    text: "Collapse all"
                    onClicked: {
                        setPasswordWarning.collapse()
                        secondCollapsibleWarning.collapse()
                        thirdCollapsibleWarning.collapse()
                    }
                }
                Button {
                    text: "Expand all"
                    onClicked: {
                        setPasswordWarning.expand()
                        secondCollapsibleWarning.expand()
                        thirdCollapsibleWarning.expand()
                    }
                }
            }

            RowLayout {
                Label { text: "Dismissible:" }
                Button {
                    text: "Activate"
                    onClicked: dismissibleWarning.show()
                }
                Button {
                    text: "Show for 5 s"
                    onClicked: dismissibleWarning.showFor(5000)
                }

                ToolSeparator {}

                Label { text: "No close button:" }
                Button {
                    text: "Activate"
                    onClicked: noCloseWarning.show()
                }
                Button {
                    text: "Show for 5 s"
                    onClicked: noCloseWarning.showFor(5000)
                }

                ToolSeparator {}

                Label { text: "Width:" }
                Slider {
                    id: ctrlWidth
                    from: 300
                    to: 1600
                    value: 800
                }
            }
        }
    }
}

// category: Panels
// status: decent
