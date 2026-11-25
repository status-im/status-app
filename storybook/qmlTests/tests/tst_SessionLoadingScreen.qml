import QtQuick
import QtTest

import mainui

Item {
    id: root
    width: 600
    height: 800

    Component {
        id: loadingScreenComponent

        SessionLoadingScreen {
            property bool accepts: true
            property int reloginCount: 0
            relogin: () => { reloginCount++; return accepts }
        }
    }

    Component {
        id: viewComponent

        SessionTransitionView {
            anchors.fill: parent
            phase: SessionTransitionView.Phase.Ending
        }
    }

    TestCase {
        name: "SessionLoadingScreen"
        when: windowShown

        function createLoadingScreen(props) {
            const screen = createTemporaryObject(loadingScreenComponent, root, props)
            verify(!!screen)
            return screen
        }

        function test_shownAtStartUntilTheSessionContentLoads() {
            const screen = createLoadingScreen()
            compare(screen.shown, true)
            screen.sessionContentLoaded()
            compare(screen.shown, false)
        }

        // A boot login still in progress adopted by the login screen: the onboarding
        // content already loaded when the record refresh relogin starts
        function test_anAcceptedReloginAfterTheContentLoadedShowsItAgain() {
            const screen = createLoadingScreen()
            const view = createTemporaryObject(viewComponent, root)
            view.unrequestedEnd = Qt.binding(() => screen.unrequestedRelogin)
            screen.sessionContentLoaded()

            compare(screen.startUnrequestedRelogin(), true)
            compare(screen.reloginCount, 1)
            compare(screen.shown, true)
            compare(view.showsProgress, false)

            screen.sessionContentLoaded()
            compare(screen.shown, false)
            compare(screen.unrequestedRelogin, false)
            compare(view.showsProgress, true)
        }

        // Logged in at start: the loading screen is still up when the relogin starts
        function test_anAcceptedReloginBeforeTheContentLoadedKeepsItShown() {
            const screen = createLoadingScreen()
            compare(screen.startUnrequestedRelogin(), true)
            compare(screen.shown, true)
            screen.sessionContentLoaded()
            compare(screen.shown, false)
        }

        function test_anIgnoredReloginLeavesTheContentShown() {
            const screen = createLoadingScreen({ accepts: false })
            screen.sessionContentLoaded()
            compare(screen.startUnrequestedRelogin(), false)
            compare(screen.shown, false)
            compare(screen.unrequestedRelogin, false)
        }
    }
}
