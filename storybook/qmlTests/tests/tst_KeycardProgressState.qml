import QtQuick

import QtTest

import utils

import shared.popups.keycard_new.states 1.0

/*!
    KeycardProgressState is a pure state machine with no fallback: `failure` is bound to
    \c root.failure rather than acting as a catch-all, so a card state that matches no \c when
    clause applies no PropertyChanges at all and the step renders blank.

    The readKeycard flow pins both \c processing and \c failure to false and is therefore driven
    solely by the card state, which makes every unmapped value visible to the user there.
*/
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
                // Reached while a retry restarts the operation with a newly supplied pairing
                // password: the card still reports the previous failure until detection produces
                // a fresh status.
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
    }
}
