import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core.Theme

import shared.views

import utils

Control {
    id: root

    property var sharedKeycardModule

    signal passwordMatch(bool result)

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        PasswordConfirmationView {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: Theme.bigPadding

            expectedPassword: root.sharedKeycardModule.getNewPassword()

            Component.onCompleted: {
                forceInputFocus()
            }

            onPasswordMatchChanged: {
                root.passwordMatch(passwordMatch)
            }

            onSubmit: {
                if(passwordMatch) {
                    root.sharedKeycardModule.currentState.doPrimaryAction()
                }
            }
        }
    }
}
