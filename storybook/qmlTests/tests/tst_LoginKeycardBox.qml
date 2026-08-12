import QtQuick

import QtTest

import StatusQ.Core.Theme

import AppLayouts.Onboarding.components
import AppLayouts.Onboarding.enums

Item {
    id: root

    width: 400
    height: 400

    Component {
        id: componentUnderTest

        LoginKeycardBox {
            keycardState: Onboarding.KeycardState.NotEmpty
            isWrongKeycard: false
            keycardRemainingPinAttempts: 3
            keycardRemainingPukAttempts: 5
            isBiometricsLogin: false
            biometricsSuccessful: false
            biometricsFailed: false
        }
    }

    property var box

    SignalSpy {
        id: submittedSpy
        target: root.box
        signalName: "pairingPasswordSubmitted"
    }

    TestCase {
        name: "LoginKeycardBox_pairingPassword"
        when: windowShown

        function init() {
            box = createTemporaryObject(componentUnderTest, root)
            verify(!!box)
            submittedSpy.clear()
        }

        function passwordInput() {
            return findChild(box, "keycardPairingPasswordInput")
        }

        function continueButton() {
            return findChild(box, "btnSubmitPairingPassword")
        }

        function test_hiddenUntilPairingPasswordIsRequired() {
            verify(!passwordInput().visible, "the pairing password input must stay hidden")
            verify(!continueButton().visible, "the Continue button must stay hidden")
        }

        function test_shownWhenPairingPasswordIsRequired() {
            box.keycardState = Onboarding.KeycardState.PairingPasswordRequired

            verify(passwordInput().visible, "expected the pairing password input")
            verify(continueButton().visible, "expected a Continue button to submit it")
            verify(!findChild(box, "pinInput").visible,
                   "the PIN input must give way to the pairing password input")
        }

        function test_continueIsDisabledUntilSomethingIsTyped() {
            box.keycardState = Onboarding.KeycardState.PairingPasswordRequired

            verify(!continueButton().enabled, "an empty pairing password must not be submittable")

            passwordInput().text = "MyCustomPass"
            verify(continueButton().enabled)
        }

        function test_continueSubmitsThePairingPassword() {
            box.keycardState = Onboarding.KeycardState.PairingPasswordRequired
            passwordInput().text = "MyCustomPass"

            continueButton().clicked()

            compare(submittedSpy.count, 1, "expected the login to be retried")
            compare(box.pairingPassword, "MyCustomPass",
                    "the entered password must be readable by the login screen")
        }

        function test_enterSubmitsThePairingPassword() {
            box.keycardState = Onboarding.KeycardState.PairingPasswordRequired
            passwordInput().text = "MyCustomPass"

            passwordInput().accepted()

            compare(submittedSpy.count, 1, "Enter must submit as well as the Continue button")
        }

        function test_enterDoesNothingWhenEmpty() {
            box.keycardState = Onboarding.KeycardState.PairingPasswordRequired

            passwordInput().accepted()

            compare(submittedSpy.count, 0)
        }
    }

    TestCase {
        name: "LoginKeycardBox_cardStates"
        when: windowShown

        function init() {
            box = createTemporaryObject(componentUnderTest, root)
            verify(!!box)
        }

        function infoText() {
            return findChild(box, "loginKeycardInfoText")
        }

        function pinInput() {
            return findChild(box, "pinInput")
        }

        function test_insertKeycardShowsWaitingForCard() {
            box.keycardState = Onboarding.KeycardState.InsertKeycard

            compare(box.state, "insert")
            compare(infoText().text, "Tap or insert your Keycard...")
            verify(!pinInput().visible, "PIN must stay hidden until a card is present")
        }

        function test_wrongKeycardShowsError() {
            box.isWrongKeycard = true

            compare(box.state, "wrongKeycard")
            compare(infoText().text, "Wrong Keycard for this profile")
            compare(infoText().color, Theme.palette.dangerColor1)
            verify(pinInput().visible, "wrong-keycard extends notEmpty and keeps the PIN field")
        }

        function test_blockedShowsUnblock_data() {
            return [
                {tag: "blocked-pin", keycardState: Onboarding.KeycardState.BlockedPIN},
                {tag: "blocked-puk", keycardState: Onboarding.KeycardState.BlockedPUK},
            ]
        }

        function test_blockedShowsUnblock(data) {
            box.keycardState = data.keycardState

            compare(box.state, "blocked")
            compare(infoText().text, "Keycard blocked")
            verify(findChild(box, "btnUnblock").visible)
            verify(!pinInput().visible)
        }
    }
}
