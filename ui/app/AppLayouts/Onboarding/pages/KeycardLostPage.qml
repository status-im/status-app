import QtQuick

import StatusQ.Controls
import StatusQ.Core.Theme

import AppLayouts.Onboarding.controls

import utils

KeycardBasePage {
    id: root

    signal createReplacementKeycardRequested()
    signal useProfileWithoutKeycardRequested()

    title: qsTr("Lost Keycard")
    subtitle: qsTr("Sorry you've lost your Keycard")
    image.source: Assets.png("keycard/wrong_card/empty")

    buttons: [
        StatusButton {
            objectName: "createReplacementButton"
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, parent.width - 2*Theme.bigPadding)
            text: qsTr("Create replacement Keycard using the same recovery phrase")
            onClicked: root.createReplacementKeycardRequested()

            /////////////////////////////////////////////////////////////////////////////////
            // # Remove this once we implement unlock via PUK
            /////////////////////////////////////////////////////////////////////////////////
            enabled: false
            MouseArea {
                id: createReplacementArea
                anchors.fill: parent
                hoverEnabled: true
            }
            StatusToolTip {
                text: Constants.keycard.temporarilyUnavailable
                visible: createReplacementArea.containsMouse
            }
            /////////////////////////////////////////////////////////////////////////////////
        },
        StatusButton {
            objectName: "startUsingWithoutKeycardButton"
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Start using this profile without Keycard")
            onClicked: root.useProfileWithoutKeycardRequested()

            /////////////////////////////////////////////////////////////////////////////////
            // # Remove this once we implement unlock via PUK
            /////////////////////////////////////////////////////////////////////////////////
            enabled: false
            MouseArea {
                id: startWithoutKeycardArea
                anchors.fill: parent
                hoverEnabled: true
            }
            StatusToolTip {
                text: Constants.keycard.temporarilyUnavailable
                visible: startWithoutKeycardArea.containsMouse
            }
            /////////////////////////////////////////////////////////////////////////////////
        }
    ]

    StatusButton {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 28

        isOutline: true

        size: StatusBaseButton.Size.Small
        text: qsTr("Order a new Keycard")
        icon.name: "external-link"
        icon.width: 24
        icon.height: 24
        onClicked: requestOpenLink("https://keycard.tech/")
    }
}
