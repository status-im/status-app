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

        // A state flicker (an intent bringing the app back) is no exit.
        function test_comingBackWithinTheGraceKeepsTheLayout() {
            const policy = makePolicy({ shown: true, dropGrace: 100 })

            policy.shown = false
            policy.shown = true
            wait(200)

            verify(policy.keepLoaded)
            compare(policy.droppings, 0)
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
            policy.memoryPressure()

            verify(policy.keepLoaded)
            compare(policy.idleDrops, 1)
        }

        function test_theLastReasonEndingRestartsTheDelay() {
            const policy = makePolicy({ shown: true, hasLivePage: true, keepAlive: true,
                                        dropDelay: 60000 })
            policy.shown = false
            policy.memoryPressure()
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
            wait(100)

            verify(policy.keepLoaded)
        }

        function test_aReasonOnTheWayOutStillDelays() {
            const policy = makePolicy({ shown: true, keepAlive: true })

            policy.shown = false

            verify(policy.keepLoaded)
        }
    }
}
