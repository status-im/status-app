import QtQuick

import QtTest

import AppLayouts.Onboarding.components 1.0
import AppLayouts.Onboarding.enums 1.0

/*!
    Covers the custom pairing password step on the login screen: a card provisioned outside the
    app (e.g. on the Keycard shell) rejects the default pairing password, and the box has to
    collect the user's password and hand it back so the login can be re-run.

    Submitting is deliberately a separate signal from loginRequested(): every keycard login
    failure is reported as a wrong PIN, which clears the PIN input, so the box has no PIN left to
    re-send. The login screen keeps the last PIN and re-issues the login itself.
*/
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
}
