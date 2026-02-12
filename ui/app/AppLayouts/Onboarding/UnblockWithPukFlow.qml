import QtQuick

import StatusQ.Controls
import StatusQ.Core.Theme

import AppLayouts.Onboarding.pages
import AppLayouts.Onboarding.enums

OnboardingStackView {
    id: root

    required property int keycardState
    required property int pinSettingState
    required property var tryToSetPukFunction
    required property int remainingAttempts
    required property int keycardPinInfoPageDelay

    signal setPinRequested(string pin)
    signal keycardFactoryResetRequested
    signal finished(bool success)

    initialItem: d.initialComponent()

    function reset() {
        clear()
        push(d.initialComponent())
    }

    QtObject {
        id: d

        function initialComponent() {
            if (root.keycardState === Onboarding.KeycardState.BlockedPIN)
                return keycardEnterPukPage
            if (root.keycardState === Onboarding.KeycardState.Empty ||
                    root.keycardState === Onboarding.KeycardState.NotEmpty)
                return keycardUnblockedPage
            return keycardIntroPage
        }

        function finishWithFactoryReset() {
            root.keycardFactoryResetRequested()
            root.finished(false)
        }
    }

    Component {
        id: keycardIntroPage

        KeycardIntroPage {
            keycardState: root.keycardState
            unblockWithPukAvailable: root.remainingAttempts > 0
            unblockUsingSeedphraseAvailable: true
            factoryResetAvailable: !unblockWithPukAvailable
            onKeycardFactoryResetRequested: d.finishWithFactoryReset()
            onEmptyKeycardDetected: root.replace(keycardUnblockedPage)
            onNotEmptyKeycardDetected: root.replace(keycardUnblockedPage)
            onUnblockWithPukRequested: root.push(keycardEnterPukPage)
        }
    }

    Component {
        id: keycardEnterPukPage

        KeycardEnterPukPage {
            tryToSetPukFunction: root.tryToSetPukFunction
            remainingAttempts: root.remainingAttempts
            onKeycardPukEntered: (puk) => root.replace(keycardCreatePinPage)
            onKeycardFactoryResetRequested: d.finishWithFactoryReset()
        }
    }

    Component {
        id: keycardCreatePinPage

        KeycardCreatePinDelayedPage {
            pinSettingState: root.pinSettingState
            authorizationState: Onboarding.AuthorizationState.Authorized // authorization not needed
            keycardPinInfoPageDelay: root.keycardPinInfoPageDelay

            onSetPinRequested: (pin) => root.setPinRequested(pin)
            onFinished: root.replace(keycardUnblockedPage,
                                     { title: qsTr("Unblock successful") })
        }
    }

    Component {
        id: keycardUnblockedPage

        KeycardBasePage {
            image.source: Assets.png("keycard/card_inserted/writing-positive")
            title: qsTr("Your Keycard is already unblocked!")
            buttons: [
                StatusButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Continue")
                    onClicked: root.finished(true)
                }
            ]
        }
    }
}
