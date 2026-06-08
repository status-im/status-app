import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import shared.popups

SplitView {
    id: root

    Logs { id: logs }

    orientation: Qt.Vertical

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        SettingsDirtyToastMessage {
            id: toast

            anchors.centerIn: parent
            width: ctrlWidth.value

            active: ctrlActive.checked
            loading: ctrlLoading.checked
            cancelButtonVisible: ctrlCancelVisible.checked
            saveForLaterButtonVisible: ctrlSaveForLaterVisible.checked
            saveChangesButtonEnabled: ctrlSaveEnabled.checked
            type: ctrlInfoType.checked ? SettingsDirtyToastMessage.Type.Info
                                       : SettingsDirtyToastMessage.Type.Danger
            saveChangesTooltipText: ctrlSaveEnabled.checked
                                    ? "" : "Save is disabled"

            additionalComponent.text: ctrlAdditional.checked
                                       ? "Some additional information" : ""
            additionalComponent.visible: ctrlAdditional.checked

            onSaveChangesClicked: logs.logEvent("onSaveChangesClicked")
            onSaveForLaterClicked: logs.logEvent("onSaveForLaterClicked")
            onResetChangesClicked: logs.logEvent("onResetChangesClicked")
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 150
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            RowLayout {
                Switch {
                    id: ctrlActive
                    text: "active"
                    checked: true
                }

                Switch {
                    id: ctrlLoading
                    text: "loading"
                    checked: false
                }

                Switch {
                    id: ctrlSaveEnabled
                    text: "saveChangesButtonEnabled"
                    checked: true
                }

                Switch {
                    id: ctrlCancelVisible
                    text: "cancelButtonVisible"
                    checked: true
                }

                Switch {
                    id: ctrlSaveForLaterVisible
                    text: "saveForLaterButtonVisible"
                    checked: false
                }
            }

            RowLayout {
                Switch {
                    id: ctrlInfoType
                    text: "Info type (off = Danger)"
                    checked: false
                }

                Switch {
                    id: ctrlAdditional
                    text: "additional component"
                    checked: false
                }

                Button {
                    text: "notifyDirty()"
                    onClicked: toast.notifyDirty()
                }

                ToolSeparator {}

                Label { text: "Width:" }
                Slider {
                    id: ctrlWidth
                    from: 300
                    to: 900
                    value: 500
                }
            }
        }
    }
}

// category: Popups
// status: good
