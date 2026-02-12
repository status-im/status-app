import QtQuick

import StatusQ.Core
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import AppLayouts.Onboarding.pages
import AppLayouts.Onboarding.enums

OnboardingStackView {
    id: root

    required property int keycardState
    property bool fromLoginScreen

    signal performKeycardFactoryResetRequested

    signal finished

    initialItem: root.keycardState === Onboarding.KeycardState.FactoryResetting
                 ? keycardResetPageComponent : keycardResetAcks

    Component {
        id: keycardResetAcks

        KeycardBasePage {
            image.source: Assets.png("keycard/factory_reset/keycard-factory-reset")
            title: qsTr("Factory reset Keycard")
            subtitle: "<font color='%1'>".arg(Theme.palette.dangerColor1) +
                      qsTr("All data including the stored key pair and derived accounts will be removed from the Keycard") +
                      "</font>"
            buttons: [
                StatusCheckBox {
                    id: ack
                    width: Math.min(implicitWidth, parent.width)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("I understand the key pair will be deleted")
                },
                Item {
                    width: parent.width
                    height: parent.spacing
                },
                StatusButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    type: StatusBaseButton.Type.Danger
                    text: qsTr("Factory reset this Keycard")
                    enabled: ack.checked
                    onClicked: {
                        root.performKeycardFactoryResetRequested()
                        root.replace(null, keycardResetPageComponent)
                    }
                }
            ]
        }
    }

    Component {
        id: keycardResetPageComponent

        KeycardBasePage {
            id: keycardResetPage
            readonly property bool backAvailableHint: false
            readonly property bool resetting: root.keycardState === Onboarding.KeycardState.FactoryResetting

            image.source: resetting ? Assets.png("keycard/factory_reset/keycard-factory-reset")
                                    : Assets.png("keycard/factory_reset/keycard-factory-reset-positive")
            title: resetting ? qsTr("Reseting Keycard") : qsTr("Keycard successfully factory reset")
            subtitle: resetting ? "" : qsTr("You can now use this Keycard like it's a brand-new, empty Keycard")
            infoText.text: resetting ? qsTr("Do not remove your Keycard or reader") : ""
            buttons: [
                Row {
                    spacing: 4
                    visible: keycardResetPage.resetting
                    anchors.horizontalCenter: parent.horizontalCenter
                    StatusLoadingIndicator {
                        color: Theme.palette.directColor1
                    }
                    StatusBaseText {
                        text: qsTr("Please wait while the Keycard is being reset")
                    }
                },
                StatusButton {
                    visible: !keycardResetPage.resetting
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 320
                    text: root.fromLoginScreen ? qsTr("Back to Login screen")
                                               : qsTr("Log in or Create profile")
                    onClicked: root.finished()
                }
            ]
        }
    }
}
