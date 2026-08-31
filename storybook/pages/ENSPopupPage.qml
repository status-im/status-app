import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import AppLayouts.Profile.popups

SplitView {
    orientation: Qt.Vertical

    Logs { id: logs }

    QtObject {
        id: d

        property string preferredUsername: ""
    }

    ListModel {
        id: ensUsernamesModel

        ListElement { ensUsername: "alice.stateofus.eth" }
        ListElement { ensUsername: "alice.eth" }
        ListElement { ensUsername: "bob.stateofus.eth" }
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

        ENSPopup {
            id: popup

            anchors.centerIn: parent
            visible: true
            modal: false
            destroyOnClose: false
            closePolicy: Popup.NoAutoClose

            preferredUsername: d.preferredUsername
            model: ensUsernamesModel

            onPreferredUsernameSelected: (ensUsername) => {
                d.preferredUsername = ensUsername
                logs.logEvent("ENSPopup::preferredUsernameSelected: " + ensUsername)
            }
        }
    }

    LogsAndControlsPanel {
        id: logsAndControlsPanel

        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 160

        logsView.logText: logs.logText

        ColumnLayout {
            Button {
                text: "Clear preferred username"

                onClicked: d.preferredUsername = ""
            }
        }
    }
}

// category: Popups
