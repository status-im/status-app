import QtQuick

import StatusQ.Core.Theme

import AppLayouts.Onboarding.controls

KeycardBasePage {
    id: root

    signal createProfileWithEmptyKeycardRequested()

    title: qsTr("Keycard is empty")
    subtitle: qsTr("There is no profile key pair on this Keycard")
    image.source: Assets.png("keycard/wrong_card/empty")

    buttons: [
        MaybeOutlineButton {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Create new profile on this Keycard")
            onClicked: root.createProfileWithEmptyKeycardRequested()
        }
    ]
}
