import QtCore
import QtQuick
import QtQuick.Controls

import Models
import Storybook

import shared.popups

SplitView {
    id: root

    Logs { id: logs }

    orientation: Qt.Vertical

    function createAndOpenDialog() {
        dlgComponent.createObject(popupBg).open()
    }

    Component.onCompleted: createAndOpenDialog()

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        PopupBackground {
            id: popupBg
            anchors.fill: parent

            Button {
                anchors.centerIn: parent
                text: "Reopen"

                onClicked: createAndOpenDialog()
            }
        }

        Component {
            id: dlgComponent
            EnableMessageBackupPopup {
                anchors.centerIn: parent
                visible: true
                modal: false
                onAccepted: logs.logEvent("EnableMessageBackupPopup::onAccepted")
                onClosed: logs.logEvent("EnableMessageBackupPopup::onClosed")

                destroyOnClose: true
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200

        logsView.logText: logs.logText
    }
}

// category: Popups
// status: good
