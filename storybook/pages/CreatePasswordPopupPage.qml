import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import shared.popups

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

        CreatePasswordPopup {
            id: popup

            modal: false
            closePolicy: Popup.CloseOnEscape

            title: ctrlCopyTitle.checked ? "Set password to copy address" : qsTr("Create profile password")
            passwordStrengthScoreFunction: (password) => Math.min(4, Math.floor(password.length / 3))
            stayLoggedInAvailable: ctrlStayLoggedIn.checked
            biometricsAvailable: ctrlBiometrics.checked
            loading: ctrlLoading.checked
            errorText: ctrlError.checked ? "The password could not be set. Please try again." : ""

            onSubmitted: (password, stayLoggedIn, enableBiometrics) =>
                         logs.logEvent("submitted", ["password", "stayLoggedIn", "enableBiometrics"], arguments)
        }

        Component.onCompleted: popup.open()
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText

        ColumnLayout {
            Switch {
                id: ctrlStayLoggedIn
                text: "Stay logged in available"
                checked: true
            }
            Switch {
                id: ctrlBiometrics
                text: "Biometrics available"
                checked: true
            }
            Switch {
                id: ctrlLoading
                text: "Loading"
            }
            Switch {
                id: ctrlError
                text: "Error"
            }
            Switch {
                id: ctrlCopyTitle
                text: "Copy-address title"
            }
        }
    }
}

// category: Popups
// status: good
