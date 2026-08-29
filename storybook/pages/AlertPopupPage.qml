import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook
import Models

import shared.popups

SplitView {
    Logs { id: logs }

    SplitView {
        orientation: Qt.Vertical
        SplitView.fillWidth: true

        Item {
            SplitView.fillWidth: true
            SplitView.fillHeight: true

            PopupBackground {
                anchors.fill: parent
            }

            Button {
                anchors.centerIn: parent
                text: "Reopen"

                onClicked: dialog.open()
            }

            AlertPopup {
                id: dialog

                title: qsTr("Remotely destruct %n token(s)", "", 12)
                acceptBtnText: qsTr("Remotely destruct")
                alertText: qsTr("Continuing will destroy tokens held by members and revoke any perissions they given. To undo you will have to issue them new tokens.")

                onAcceptClicked: logs.logEvent("AlertPopup::onAcceptClicked")
                onCancelClicked: logs.logEvent("AlertPopup::onCancelClicked")

                Binding on asset.name {
                    when: ctrlIcon.checked
                    value: "settings"
                }
            }
        }

        LogsAndControlsPanel {
            id: logsAndControlsPanel

            SplitView.minimumHeight: 100
            SplitView.preferredHeight: 150

            logsView.logText: logs.logText

            CheckBox {
                id: ctrlIcon
                text: "With icon"
            }
        }
    }
}

// category: Popups
// status: good
