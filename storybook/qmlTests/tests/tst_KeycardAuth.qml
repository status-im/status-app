import QtQuick

import QtTest

import shared.popups.auth_sign_base.states

import utils

Item {
    id: root

    width: 480
    height: 520

    Component {
        id: componentUnderTest

        KeycardAuth {
            width: root.width
            height: root.height
            userProfilePublicKey: "0xpub"
            keycardState: Constants.keycard.state.waitingForCard
            keycardInternalError: false
            wrongKeycardProfile: false
            keyPairForProcessing: null
        }
    }

    TestCase {
        name: "KeycardAuth_pinLoaderStates"
        when: windowShown

        function test_states_data() {
            return [
                {
                    tag: "waiting-for-card",
                    keycardState: Constants.keycard.state.waitingForCard,
                    wrongKeycardProfile: false,
                    expectedState: "waiting-for-card",
                    expectedTitle: "Tap or insert Keycard..."
                },
                {
                    tag: "reading-card-connecting",
                    keycardState: Constants.keycard.state.connectingCard,
                    wrongKeycardProfile: false,
                    expectedState: "reading-card",
                    expectedTitle: "Reading Keycard..."
                },
                {
                    tag: "reading-card-ready",
                    keycardState: Constants.keycard.state.ready,
                    wrongKeycardProfile: false,
                    expectedState: "reading-card",
                    expectedTitle: "Reading Keycard..."
                },
                {
                    tag: "wrong-keycard-profile",
                    keycardState: Constants.keycard.state.ready,
                    wrongKeycardProfile: true,
                    expectedState: "wrong-keycard-profile",
                    expectedTitle: "Wrong Keycard inserted"
                },
                {
                    tag: "auth-success",
                    keycardState: Constants.keycard.state.authorized,
                    wrongKeycardProfile: false,
                    expectedState: "auth-success",
                    expectedTitle: "Success"
                },
                {
                    tag: "blocked-pin",
                    keycardState: Constants.keycard.state.blockedPIN,
                    wrongKeycardProfile: false,
                    expectedState: "blocked-pin",
                    expectedTitle: "Keycard locked",
                    expectedMessage: "PIN entered incorrectly too many times"
                },
                {
                    tag: "blocked-puk",
                    keycardState: Constants.keycard.state.blockedPUK,
                    wrongKeycardProfile: false,
                    expectedState: "blocked-puk",
                    expectedTitle: "Keycard locked",
                    expectedMessage: "PUK entered incorrectly too many times"
                },
            ]
        }

        function test_states(data) {
            const auth = createTemporaryObject(componentUnderTest, root, {
                                                   keycardState: data.keycardState,
                                                   wrongKeycardProfile: data.wrongKeycardProfile
                                               })
            verify(!!auth)
            compare(auth.state, data.expectedState)
            compare(findChild(auth, "keycardAuthTitle").text, data.expectedTitle)
            if (data.expectedMessage)
                compare(findChild(auth, "keycardAuthMessage").text, data.expectedMessage)
        }

        function test_connectingCardShowsLoader() {
            const auth = createTemporaryObject(componentUnderTest, root, {
                                                   keycardState: Constants.keycard.state.connectingCard
                                               })
            verify(!!auth)
            const loader = findChild(auth, "keycardAuthLoadingIndicator")
            verify(!!loader)
            verify(loader.visible)
        }
    }
}
