import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import shared.popups

import Storybook

import utils

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

        EnableBiometricsPopup {
            id: popup

            modal: false
            closePolicy: Popup.CloseOnEscape

            loading: loadingctrl.checked
            errorText: ""

            onEnableBiometricsRequested: () => {
                logs.logEvent("EnableBiometricsRequested")
            }
        }

        Component.onCompleted: popup.open()
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        Switch {
            id: loadingctrl

            text: "loading"
            checked: false
        }
    }
}

// category: Popups
// status: good
