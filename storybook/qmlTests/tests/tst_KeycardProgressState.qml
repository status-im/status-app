import QtQuick

import QtTest

import utils

import shared.popups.keycard_new.states

Item {
    id: root

    width: 400
    height: 400

    Component {
        id: componentUnderTest

        KeycardProgressState {
            keycardState: ""
            keycardInternalError: false
            keycardNotEmptyError: false
            wrongKeycard: false
            wrongKeycardProfile: false
            wrongPin: false
            remainingPinAttempts: 3
            wrongPuk: false
            remainingPukAttempts: 5
            keycardInteractionCompleted: false
            processing: false
            processingImage: ""
            success: false
            successImage: ""
            failure: false
            failureImage: ""
        }
    }

    TestCase {
        name: "KeycardProgressState"
        when: windowShown

        function test_cardStatesRenderSomething_data() {
            return [
                {tag: "empty", keycardState: ""},
                {tag: "unknown-reader-state", keycardState: Constants.keycard.state.unknownReaderState},
                {tag: "waiting-for-reader", keycardState: Constants.keycard.state.waitingForReader},
                {tag: "waiting-for-card", keycardState: Constants.keycard.state.waitingForCard},
                {tag: "ready", keycardState: Constants.keycard.state.ready},
                {tag: "pairing-error", keycardState: Constants.keycard.state.pairingError},
            ]
        }

        function test_cardStatesRenderSomething(data) {
            const progress = createTemporaryObject(componentUnderTest, root,
                                                   {keycardState: data.keycardState})
            verify(!!progress)
            verify(progress.contentItem.state !== "",
                   "no state matched '%1', so the step would render blank".arg(data.keycardState))
        }

        function test_blockedAndFailureStates_data() {
            return [
                {
                    tag: "blocked-pin",
                    props: {
                        failure: true,
                        keycardState: Constants.keycard.state.blockedPIN
                    },
                    expectedState: "blocked-pin",
                    expectedTitle: "Keycard is blocked",
                    expectedMessage: "Keycard is blocked due to three failed PIN input attempts"
                },
                {
                    tag: "blocked-puk",
                    props: {
                        failure: true,
                        keycardState: Constants.keycard.state.blockedPUK
                    },
                    expectedState: "blocked-puk",
                    expectedTitle: "Keycard is blocked",
                    expectedMessage: "Keycard is blocked due to five failed PUK input attempts"
                },
            ]
        }

        function test_blockedAndFailureStates(data) {
            const progress = createTemporaryObject(componentUnderTest, root, data.props)
            verify(!!progress)
            compare(progress.contentItem.state, data.expectedState)
            compare(findChild(progress, "keycardProgressTitle").text, data.expectedTitle)
            compare(findChild(progress, "keycardProgressMessage").text, data.expectedMessage)
        }
    }
}
