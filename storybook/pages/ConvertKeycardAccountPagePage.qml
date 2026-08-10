import QtCore
import QtQuick

import QtQuick.Controls

import StatusQ.Core.Backpressure

import AppLayouts.Onboarding.pages
import AppLayouts.Onboarding.enums

import Storybook

Item {
    id: root

    Logs {
        id: logs
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Vertical

        ConvertKeycardAccountPage {
            id: progressPage

            SplitView.fillWidth: true
            SplitView.fillHeight: true

            convertKeycardAccountState: ctrlState.currentValue
            restartRequired: ctrlRestartRequired.checked
            onRestartRequested: {
                logs.logEvent("restartRequested")
            }
            onBackToLoginRequested: {
                logs.logEvent("backToLoginRequested")
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 200

            logsView.logText: logs.logText
        }
    }

    ComboBox {
        id: ctrlState
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 300
        textRole: "name"
        valueRole: "value"
        model: Onboarding.getModelFromEnum("ProgressState")
    }

    Switch {
        id: ctrlRestartRequired
        anchors.right: ctrlState.left
        anchors.rightMargin: 8
        anchors.verticalCenter: ctrlState.verticalCenter
        text: "Restart required (legacy profile)"
        checked: true
    }

    Settings {
        property alias convertKeycardAccountPageState: ctrlState.currentIndex
    }
}

// category: Onboarding
// status: good
// https://www.figma.com/design/Lw4nPYQcZOPOwTgETiiIYo/Desktop-Onboarding-Redesign?node-id=221-23716&node-type=frame&m=dev
// https://www.figma.com/design/Lw4nPYQcZOPOwTgETiiIYo/Desktop-Onboarding-Redesign?node-id=224-20891&node-type=frame&m=dev
// https://www.figma.com/design/Lw4nPYQcZOPOwTgETiiIYo/Desktop-Onboarding-Redesign?node-id=221-23788&node-type=frame&m=dev
