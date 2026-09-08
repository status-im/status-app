import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import AppLayouts.Onboarding.controls

SplitView {
    id: root

    Logs { id: logs }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        ColumnLayout {
            SplitView.fillHeight: true
            SplitView.fillWidth: true

            LoginPasswordInput {
                Layout.alignment: Qt.AlignCenter
                Layout.margins: 16

                enabled: enabledCheckBox.checked
                hasError: hasErrorCheckBox.checked
                placeholderText: placeholderInput.text

                isBiometricsLogin: biometricsLoginCheckBox.checked
                biometricsSuccessful: biometricsSuccessfulCheckBox.checked
                biometricsFailed: biometricsFailedCheckBox.checked

                onBiometricsRequested: logs.logEvent("onBiometricsRequested")
                onTextEdited: logs.logEvent("onTextEdited", ["text"], [text])
                onAccepted: logs.logEvent("onAccepted", ["text"], [text])
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 200

            logsView.logText: logs.logText
        }
    }

    Pane {
        SplitView.minimumWidth: 300
        SplitView.preferredWidth: 300

        ColumnLayout {
            TextField {
                id: placeholderInput
                text: "Password"
            }
            CheckBox {
                id: enabledCheckBox
                text: "enabled"
                checked: true
            }
            CheckBox {
                id: hasErrorCheckBox
                text: "hasError"
            }
            CheckBox {
                id: biometricsLoginCheckBox
                text: "isBiometricsLogin"
            }
            CheckBox {
                id: biometricsSuccessfulCheckBox
                text: "biometricsSuccessful"
                enabled: biometricsLoginCheckBox.checked
            }
            CheckBox {
                id: biometricsFailedCheckBox
                text: "biometricsFailed"
                enabled: biometricsLoginCheckBox.checked
            }
        }
    }
}

// category: Onboarding
