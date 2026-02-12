import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import StatusQ.Core.Theme

import shared.stores
import shared.views

import utils

Control {
    id: root

    property var sharedKeycardModule

    signal passwordValid(bool valid)

    topPadding: Theme.xlPadding
    bottomPadding: Theme.halfPadding
    leftPadding: Theme.xlPadding
    rightPadding: Theme.xlPadding

    contentItem: ColumnLayout {
        spacing: Theme.padding

        PasswordView {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            passwordStrengthScoreFunction: RootStore.getPasswordStrengthScore
            highSizeIntro: true

            newPswText: root.sharedKeycardModule.getNewPassword()
            confirmationPswText: root.sharedKeycardModule.getNewPassword()

            Component.onCompleted: {
                forceNewPswInputFocus()
                checkPasswordMatches()
                root.passwordValid(ready)
            }

            onReadyChanged: {
                root.passwordValid(ready)
                if (!ready) {
                    return
                }
                root.sharedKeycardModule.setNewPassword(newPswText)
            }
            onReturnPressed: {
                if(!ready) {
                    return
                }
                root.sharedKeycardModule.currentState.doPrimaryAction()
            }
        }
    }
}
