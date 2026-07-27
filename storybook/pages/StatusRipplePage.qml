import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups

import mainui

import Storybook

SplitView {
    Logs { id: logs }

    ButtonGroup {
        id: rippleOriginButtonGroup
    }

    QtObject {
        id: d

        readonly property int effectiveRippleOrigin: ctrlFollowPointer.checked
                                                     ? StatusRipple.RippleOrigin.Pointer
                                                     : StatusRipple.RippleOrigin.Center
    }

    ScrollView {
        SplitView.fillWidth: true
        SplitView.fillHeight: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: Theme.defaultBigPadding

            Pane {
                Layout.fillWidth: true

                ColumnLayout {
                    width: parent.width
                    spacing: Theme.padding

                    Label {
                        text: "Regular buttons and icons"
                        font.bold: true
                    }

                    RowLayout {
                        spacing: Theme.padding

                        StatusButton {
                            text: "StatusButton"
                            rippleEnabled: ctrlRipple.checked
                            rippleOrigin: d.effectiveRippleOrigin
                            scaleOnPressEnabled: false
                            onClicked: logs.logEvent("StatusButton clicked")
                        }

                        StatusButton {
                            icon.name: "info"
                            rippleEnabled: ctrlRipple.checked
                            rippleOrigin: d.effectiveRippleOrigin
                            scaleOnPressEnabled: false
                            onClicked: logs.logEvent("Icon StatusButton clicked")
                        }

                        StatusFlatButton {
                            text: "StatusFlatButton"
                            rippleEnabled: ctrlRipple.checked
                            rippleOrigin: d.effectiveRippleOrigin
                            scaleOnPressEnabled: false
                            onClicked: logs.logEvent("StatusFlatButton clicked")
                        }
                    }
                }
            }

            Pane {
                Layout.fillWidth: true

                ColumnLayout {
                    width: parent.width
                    spacing: Theme.padding

                    Label {
                        text: "Round and navigation buttons"
                        font.bold: true
                    }

                    RowLayout {
                        spacing: Theme.padding

                        StatusRoundButton {
                            icon.name: "close"
                            rippleEnabled: ctrlRipple.checked
                            rippleOrigin: d.effectiveRippleOrigin
                            highlighted: ctrlHighlighted.checked
                            onClicked: logs.logEvent("StatusRoundButton clicked")
                        }

                        StatusRoundButton {
                            type: StatusRoundButton.Type.Quaternary
                            icon.name: "delete"
                            rippleEnabled: ctrlRipple.checked
                            rippleOrigin: d.effectiveRippleOrigin
                            highlighted: ctrlHighlighted.checked
                            onClicked: logs.logEvent("Danger StatusRoundButton clicked")
                        }

                        PrimaryNavSidebarButton {
                            tooltipText: "Activity Center"
                            icon.name: "notification"
                            checkable: true
                            checked: ctrlHighlighted.checked
                            highlighted: ctrlHighlighted.checked
                            rippleEnabled: ctrlRipple.checked
                            rippleOrigin: d.effectiveRippleOrigin
                            thirdpartyServicesEnabled: true
                            onClicked: logs.logEvent("PrimaryNavSidebarButton clicked")
                        }
                    }
                }
            }

            Pane {
                Layout.fillWidth: true

                ColumnLayout {
                    width: parent.width
                    spacing: Theme.padding

                    Label {
                        text: "Dropdown button"
                        font.bold: true
                    }

                    StatusComboBox {
                        Layout.preferredWidth: 280
                        label: "StatusComboBox"
                        model: ["One", "Two", "Three"]
                        rippleOrigin: d.effectiveRippleOrigin
                    }
                }
            }

            Pane {
                Layout.fillWidth: true

                ColumnLayout {
                    width: parent.width
                    spacing: Theme.padding

                    Label {
                        text: "Dropdown options"
                        font.bold: true
                    }

                    StatusItemDelegate {
                        Layout.preferredWidth: 280
                        text: "StatusItemDelegate"
                        icon.name: "info"
                        icon.color: Theme.palette.primaryColor1
                        highlighted: ctrlHighlighted.checked
                        rippleOrigin: d.effectiveRippleOrigin
                        onClicked: logs.logEvent("StatusItemDelegate clicked")
                    }

                    StatusButton {
                        text: "Open StatusMenu"
                        scaleOnPressEnabled: false
                        onClicked: menu.popup()
                    }

                    StatusMenu {
                        id: menu
                        rippleOrigin: d.effectiveRippleOrigin

                        StatusAction {
                            text: "Menu option"
                            assetSettings.name: "info"
                            onTriggered: logs.logEvent("Menu option triggered")
                        }

                        StatusAction {
                            text: "Danger option"
                            type: StatusAction.Type.Danger
                            onTriggered: logs.logEvent("Danger option triggered")
                        }
                    }
                }
            }

            Pane {
                Layout.fillWidth: true

                ColumnLayout {
                    width: parent.width
                    spacing: Theme.padding

                    Label {
                        text: "List options"
                        font.bold: true
                    }

                    StatusListItem {
                        Layout.preferredWidth: 360
                        title: "StatusListItem"
                        subTitle: "Primary list option"
                        asset.name: "info"
                        highlighted: ctrlHighlighted.checked
                        rippleOrigin: d.effectiveRippleOrigin
                        onClicked: logs.logEvent("StatusListItem clicked")
                    }

                    StatusListItem {
                        Layout.preferredWidth: 360
                        title: "Danger StatusListItem"
                        subTitle: "Danger list option"
                        type: StatusListItem.Type.Danger
                        asset.name: "warning"
                        highlighted: ctrlHighlighted.checked
                        rippleOrigin: d.effectiveRippleOrigin
                        onClicked: logs.logEvent("Danger StatusListItem clicked")
                    }
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.preferredWidth: 300

        logsView.logText: logs.logText

        ColumnLayout {
            spacing: Theme.padding

            Label {
                text: "Button feedback"
                font.bold: true
            }

            CheckBox {
                id: ctrlRipple
                text: "Ripple"
                checked: true
            }

            RowLayout {
                Layout.leftMargin: Theme.defaultPadding
                enabled: ctrlRipple.checked
                opacity: enabled ? 1 : 0.5

                RadioButton {
                    id: ctrlCentered
                    text: "Centered"
                    checked: true
                    ButtonGroup.group: rippleOriginButtonGroup
                }

                RadioButton {
                    id: ctrlFollowPointer
                    text: "Follow pointer"
                    ButtonGroup.group: rippleOriginButtonGroup
                }
            }

            Label {
                Layout.topMargin: Theme.defaultBigPadding
                text: "Options state"
                font.bold: true
            }

            CheckBox {
                id: ctrlHighlighted
                text: "Highlighted"
            }
        }
    }
}

// category: Controls
// status: good
