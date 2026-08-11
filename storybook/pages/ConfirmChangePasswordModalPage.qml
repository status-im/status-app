import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AppLayouts.Profile.popups

import Storybook

SplitView {
    PopupBackground {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        Button {
            id: reopenButton
            anchors.centerIn: parent
            text: "Reopen"

            onClicked: modal.open()
        }

        ConfirmChangePasswordModal {
            id: modal

            visible: true
            modal: false
            fastPasswordChangePossible: fastPathCheckBox.checked

            onChangePasswordRequested: passwordChangedTimer.start()

            Timer {
                id: passwordChangedTimer

                interval: 2000
                repeat: false
                onTriggered: {
                    if (successFlow.checked) {
                        modal.passwordSuccessfulyChanged()
                    } else {
                        modal.close()
                    }
                }
            }
        }
    }

    LogsAndControlsPanel {
        SplitView.minimumHeight: 100
        SplitView.preferredHeight: 200
        SplitView.preferredWidth: 300

        ColumnLayout {
            CheckBox {
                id: fastPathCheckBox
                text: "Fast password change possible (DEK)"
                checked: true
            }
            CheckBox {
                id: successFlow
                text: "%1 in 2 seconds".arg(successFlow.checked ? "Success" : "Error")
                checked: true
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: "Use the modal rekey checkbox (DEK only) to force the deep restart path."
            }
        }
    }
}

// category: Popups

// https://www.figma.com/file/d0G7m8X6ELjQlFOEKQpn1g/Profile-WIP?type=design&node-id=11-111195&mode=design&t=j3guZtz78wkceVda-0
