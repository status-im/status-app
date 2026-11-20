import QtQuick
import QtTest

import AppLayouts.Browser.webview

/// The Browser-specific part of its Drop (CONTEXT: Drop, Keep-alive reason):
/// the no-live-page grace and Keep-alive reasons. The generic timing is
/// tst_SectionDropPolicy's.
Item {
    id: root

    Component {
        id: policyComponent

        BrowserDropPolicy {
            property int idleDrops: 0

            shown: false
            hasLivePage: false
            keepAlive: false
            property int droppings: 0

            dropDelay: 50
            dropGrace: 10

            onDropIdleViewsRequested: idleDrops++
            onDropping: droppings++
        }
    }

    TestCase {
        name: "BrowserDropPolicy"

        function makePolicy(props) {
            const policy = createTemporaryObject(policyComponent, root, props ?? {})
            verify(!!policy)
            return policy
        }

        function test_withoutALivePageTheLayoutGoesAtOnce() {
            const policy = makePolicy({ shown: true })

            policy.shown = false

            tryVerify(() => !policy.keepLoaded)
            compare(policy.droppings, 1, "announced before it goes")
        }

        // Short, so a state flicker (an intent bringing the app back) is no exit;
        // coming back in time is SectionDropPolicy's to keep.
        function test_withoutALivePageTheGraceApplies() {
            const policy = makePolicy({ shown: true, dropDelay: 60000, dropGrace: 3000 })

            policy.shown = false

            compare(policy.policy.dropDelay, 3000)
        }

        function test_aLivePageGoesAfterTheDelay() {
            const policy = makePolicy({ shown: true, hasLivePage: true })

            policy.shown = false
            verify(policy.keepLoaded)

            tryVerify(() => !policy.keepLoaded)
            compare(policy.idleDrops, 0)
        }

        function test_aKeepAliveReasonKeepsTheLayoutAndDropsIdleViews() {
            const policy = makePolicy({ shown: true, hasLivePage: true, keepAlive: true,
                                        dropDelay: 60000 })

            policy.shown = false
            policy.memoryPressure(true)

            verify(policy.keepLoaded)
            compare(policy.idleDrops, 1)
            compare(policy.droppings, 0, "a kept-alive renderer is never ended")
        }

        function test_theLastReasonEndingRestartsTheDelay() {
            const policy = makePolicy({ shown: true, hasLivePage: true, keepAlive: true,
                                        dropDelay: 60000 })
            policy.shown = false
            policy.memoryPressure(true)
            policy.dropDelay = 50

            policy.keepAlive = false
            verify(policy.keepLoaded, "the delay starts over")

            tryVerify(() => !policy.keepLoaded)
        }

        // The delay chosen on the way out holds while away.
        function test_theLastReasonEndingWithoutAPageWaitsTheFullDelay() {
            const policy = makePolicy({ shown: true, keepAlive: true, dropDelay: 60000,
                                        dropGrace: 10 })
            policy.shown = false

            policy.keepAlive = false

            compare(policy.policy.dropDelay, 60000)
            verify(policy.keepLoaded)
        }

        // Without drop support the layout stays from the first show on: no timer, no pressure.
        function test_aDisabledPolicyNeverDrops() {
            const policy = makePolicy({ enabled: false, dropGrace: 10, dropDelay: 10 })
            verify(!policy.keepLoaded, "nothing before the first show")

            policy.shown = true
            policy.shown = false
            policy.memoryPressure(true)

            verify(policy.keepLoaded)
            verify(policy.policy.shown, "the shared policy never sees an exit")
            compare(policy.droppings, 0)
            compare(policy.idleDrops, 0)
        }

        // In focus when the app goes to the background: it stays, no delay runs.
        function test_aBrowserInFocusStaysInTheBackground() {
            const policy = makePolicy({ shown: true, current: true, hasLivePage: true })

            policy.inBackground = true
            policy.shown = false

            verify(policy.keepLoaded)
            verify(!policy.policy.d.timer.running)
            compare(policy.droppings, 0)
        }

        function test_aBackgroundTrimSparesTheCurrentBrowser() {
            const policy = makePolicy({ shown: true, current: true, hasLivePage: true })
            policy.inBackground = true
            policy.shown = false

            policy.memoryPressure(false)

            verify(policy.keepLoaded)
            compare(policy.droppings, 0)
        }

        // Android stops the event loop in the background: the drop happens on the way out.
        function test_anOffScreenBrowserDropsWhenTheAppGoesToTheBackground() {
            const policy = makePolicy({ shown: true, current: true, hasLivePage: true,
                                        dropDelay: 60000 })
            policy.current = false
            policy.shown = false

            policy.inBackground = true

            verify(!policy.keepLoaded)
            compare(policy.droppings, 1)
        }

        function test_aHeldBrowserSurvivesTheBackgroundAndDropsBackInFront() {
            const policy = makePolicy({ shown: true, current: true, hasLivePage: true,
                                        keepAlive: true, dropDelay: 50 })
            policy.current = false
            policy.shown = false

            policy.inBackground = true
            verify(policy.keepLoaded)
            compare(policy.idleDrops, 1)

            policy.keepAlive = false
            verify(policy.keepLoaded, "nothing runs in the background")
            policy.inBackground = false

            tryVerify(() => !policy.keepLoaded)
        }

        function test_theDelayRunsOnlyInFront() {
            const policy = makePolicy({ shown: true, current: true, hasLivePage: true,
                                        dropDelay: 60000 })
            policy.current = false
            policy.shown = false
            verify(policy.policy.d.timer.running)

            policy.keepAlive = true
            policy.inBackground = true

            verify(!policy.policy.d.timer.running)
        }

        function test_aReasonOnTheWayOutStillDelays() {
            const policy = makePolicy({ shown: true, keepAlive: true })

            policy.shown = false

            verify(policy.keepLoaded)
        }
    }
}
