import QtQuick

import StatusQ.Core.Theme

import AppLayouts.Onboarding.controls

KeycardBasePage {
    id: root

    signal tryAgainRequested()
    signal factoryResetRequested()

    title: qsTr("Communication with Keycard lost")
    subtitle: qsTr("There seems to be an issue communicating with your Keycard. Reinsert the card or reader and try again.")
    image.source: Assets.png("keycard/wrong_card/something-went-wrong")

    buttons: [
        MaybeOutlineButton {
            text: qsTr("Try again")
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: root.tryAgainRequested()
        },
        MaybeOutlineButton {
            text: qsTr("Factory reset Keycard")
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: root.factoryResetRequested()
        }
    ]
}
