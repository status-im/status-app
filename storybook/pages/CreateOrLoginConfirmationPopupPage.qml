import QtQuick
import QtQuick.Controls

import mainui

import Storybook

SplitView {
    Logs { id: logs }

    orientation: Qt.Vertical

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

        CreateOrLoginConfirmationPopup {
            id: popup

            modal: false
            closePolicy: Popup.CloseOnEscape

            onContinueRequested: logs.logEvent("continueRequested")
        }

        Component.onCompleted: popup.open()
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 150

        logsView.logText: logs.logText
    }
}

// category: Popups
// status: good
