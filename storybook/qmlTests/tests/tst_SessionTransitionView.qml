import QtQuick
import QtTest

import mainui

Item {
    id: root
    width: 600
    height: 800

    Component {
        id: viewComponent

        SessionTransitionView {
            anchors.fill: parent
        }
    }

    SignalSpy {
        id: retrySpy
        signalName: "retryRequested"
    }

    SignalSpy {
        id: quitSpy
        signalName: "quitRequested"
    }

    TestCase {
        name: "SessionTransitionView"
        when: windowShown

        function createView(props) {
            const view = createTemporaryObject(viewComponent, root, props)
            verify(!!view)
            retrySpy.target = view
            quitSpy.target = view
            retrySpy.clear()
            quitSpy.clear()
            return view
        }

        function test_endingShowsProgressOnly() {
            const view = createView({ phase: SessionTransitionView.Phase.Ending })
            const title = findChild(view, "sessionTransitionTitle")
            compare(title.text, "Signing out…")
            compare(findChild(view, "sessionTransitionRetryButton").visible, false)
            compare(findChild(view, "sessionTransitionQuitButton").visible, false)
        }

        function test_timeoutsOfferQuit_data() {
            return [
                { tag: "drain", phase: SessionTransitionView.Phase.DrainTimeout,
                  title: "Finishing background work…" },
                { tag: "logout", phase: SessionTransitionView.Phase.LogoutTimeout,
                  title: "Still signing out…" },
            ]
        }

        function test_timeoutsOfferQuit(data) {
            const view = createView({ phase: data.phase })
            compare(findChild(view, "sessionTransitionTitle").text, data.title)
            compare(findChild(view, "sessionTransitionRetryButton").visible, false)

            const quitButton = findChild(view, "sessionTransitionQuitButton")
            compare(quitButton.visible, true)
            compare(quitButton.text, "Quit")
            mouseClick(quitButton)
            compare(quitSpy.count, 1)
            compare(retrySpy.count, 0)
        }

        function test_failedOffersRetryAndQuit_data() {
            return [
                { tag: "logout", phase: SessionTransitionView.Phase.LogoutFailed,
                  title: "Signing out did not complete" },
                { tag: "start", phase: SessionTransitionView.Phase.StartFailed,
                  title: "Signed out, but Status could not get ready" },
            ]
        }

        function test_failedOffersRetryAndQuit(data) {
            const view = createView({ phase: data.phase })
            compare(findChild(view, "sessionTransitionTitle").text, data.title)
            verify(findChild(view, "sessionTransitionDetails").text !== "")

            mouseClick(findChild(view, "sessionTransitionRetryButton"))
            compare(retrySpy.count, 1)
            mouseClick(findChild(view, "sessionTransitionQuitButton"))
            compare(quitSpy.count, 1)
        }

        function test_mobileClosesInsteadOfQuitting() {
            const view = createView({ phase: SessionTransitionView.Phase.DrainTimeout,
                                      isMobile: true })
            compare(findChild(view, "sessionTransitionQuitButton").text, "Close Status")
        }

        function test_requestedEndShowsProgress() {
            const view = createView({ phase: SessionTransitionView.Phase.Ending })
            compare(view.showsProgress, true)
        }

        function test_unrequestedEndLeavesTheLoadingScreenInFront_data() {
            return [
                { tag: "ending", phase: SessionTransitionView.Phase.Ending, shows: false },
                { tag: "active", phase: SessionTransitionView.Phase.Active, shows: false },
                { tag: "drain timeout", phase: SessionTransitionView.Phase.DrainTimeout, shows: true },
                { tag: "logout timeout", phase: SessionTransitionView.Phase.LogoutTimeout, shows: true },
                { tag: "logout failed", phase: SessionTransitionView.Phase.LogoutFailed, shows: true },
                { tag: "start failed", phase: SessionTransitionView.Phase.StartFailed, shows: true },
            ]
        }

        function test_unrequestedEndLeavesTheLoadingScreenInFront(data) {
            const view = createView({ phase: data.phase, unrequestedEnd: true })
            compare(view.showsProgress, data.shows)
        }
    }
}
