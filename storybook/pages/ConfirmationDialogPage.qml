import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import shared.popups

import Storybook

SplitView {
    id: root

    orientation: Qt.Horizontal

    Logs {
        id: logs
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground {
            anchors.fill: parent
        }

        Button {
            anchors.centerIn: parent
            text: "Reopen"
            onClicked: popup.open()
        }

        ConfirmationDialog {
            id: popup

            modal: false
            closeOnOverlayClick: closeOnOverlay.checked
            escapeKeyCloses: escapeCloses.checked

            headerSettings.title: titleInput.text
            confirmationText: messageInput.text
            confirmButtonLabel: confirmLabelInput.text
            cancelButtonLabel: cancelLabelInput.text
            showCancelButton: showCancel.checked
            doNotShowAgainOptionVisible: doNotShowAgainVisible.checked
            btnType: confirmDanger.checked ? "warn" : "normal"
            cancelBtnType: cancelDanger.checked ? "warn" : "normal"

            onConfirmButtonClicked: logs.logEvent("ConfirmationDialog::confirmButtonClicked doNotShowAgainChecked=" + doNotShowAgainChecked)
            onCancelButtonClicked: logs.logEvent("ConfirmationDialog::cancelButtonClicked")
            onClosed: logs.logEvent("ConfirmationDialog::closed")

            Component.onCompleted: open()
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 320
        SplitView.preferredWidth: 360
        SplitView.fillHeight: true

        logsView.logText: logs.logText

        ColumnLayout {
            Layout.fillWidth: true

            Label {
                text: "Behavior"
                font.bold: true
            }

            CheckBox {
                id: closeOnOverlay

                Layout.fillWidth: true
                text: "Close on overlay click"
                checked: true
            }

            CheckBox {
                id: escapeCloses

                Layout.fillWidth: true
                text: "Close on Escape"
                checked: true
            }

            CheckBox {
                id: doNotShowAgainVisible

                Layout.fillWidth: true
                text: "Show do not show again"
                checked: true
            }

            CheckBox {
                id: showCancel

                Layout.fillWidth: true
                text: "Cancel button"
                checked: true
            }

            Label {
                text: "Content"
                font.bold: true
                Layout.topMargin: 12
            }

            TextField {
                id: titleInput

                Layout.fillWidth: true
                text: "Confirm your action"
                placeholderText: "Title"
            }

            TextArea {
                id: messageInput

                Layout.fillWidth: true
                Layout.preferredHeight: 72
                text: "Are you sure you want to do this?"
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true

                TextField {
                    id: confirmLabelInput

                    Layout.fillWidth: true
                    text: "Confirm"
                    placeholderText: "Confirm label"
                }

                TextField {
                    id: cancelLabelInput

                    Layout.fillWidth: true
                    text: "Cancel"
                    placeholderText: "Cancel label"
                }
            }

            Label {
                text: "Buttons"
                font.bold: true
                Layout.topMargin: 12
            }

            CheckBox {
                id: confirmDanger

                Layout.fillWidth: true
                text: "Confirm danger"
                checked: true
            }

            CheckBox {
                id: cancelDanger

                Layout.fillWidth: true
                text: "Cancel danger"
                checked: true
            }
        }
    }
}

// category: Popups
