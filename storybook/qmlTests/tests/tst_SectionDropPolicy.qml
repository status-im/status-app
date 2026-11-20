import QtQuick
import QtTest

import utils

/// When a section's UI goes away while it is not on screen (a Drop).
Item {
    id: root

    Component {
        id: policyComponent

        SectionDropPolicy {
            property int droppings: 0
            property int heldDrops: 0

            shown: false
            dropDelay: 50

            onDropping: droppings++
            onDropHeld: heldDrops++
        }
    }

    TestCase {
        name: "SectionDropPolicy"

        function makePolicy(props) {
            const policy = createTemporaryObject(policyComponent, root, props ?? {})
            verify(!!policy)
            return policy
        }

        function test_nothingLoadedBeforeFirstShown() {
            const policy = makePolicy()
            verify(!policy.keepLoaded)

            policy.shown = true
            verify(policy.keepLoaded)
        }

        function test_theUiGoesAfterTheDelay() {
            const policy = makePolicy({ shown: true })

            policy.shown = false
            verify(policy.keepLoaded)

            tryVerify(() => !policy.keepLoaded)
            compare(policy.droppings, 1, "announced before it goes")
        }

        function test_comingBackBeforeTheDelayStopsIt() {
            const policy = makePolicy({ shown: true, dropDelay: 60000 })

            policy.shown = false
            verify(policy.d.timer.running)
            policy.shown = true

            verify(!policy.d.timer.running)
            verify(policy.keepLoaded)
        }

        // The app in the background with this section current: it is what
        // the user comes back to.
        function test_theCurrentSectionNeverDropsOnTheDelay() {
            const policy = makePolicy({ shown: true, current: true })

            policy.shown = false

            verify(!policy.d.timer.running)
            verify(policy.keepLoaded)
        }

        function test_leavingTheCurrentSectionStartsTheDelay() {
            const policy = makePolicy({ shown: true, current: true, dropDelay: 60000 })
            policy.shown = false

            policy.current = false

            verify(policy.d.timer.running)
        }

        function test_neverWhileShown() {
            const policy = makePolicy({ shown: true, current: true })

            policy.memoryPressure(true)
            policy.memoryPressure(false)

            verify(policy.keepLoaded)
            compare(policy.droppings, 0)
        }

        function test_pressureDropsAnySectionNotOnScreen() {
            const policy = makePolicy({ shown: true, current: true, dropDelay: 60000 })
            policy.shown = false

            policy.memoryPressure(true)

            verify(!policy.keepLoaded)
            compare(policy.droppings, 1)
        }

        // Being in the background is no pressure: only the sections the user
        // left go.
        function test_aBackgroundTrimSparesTheCurrentSection() {
            const policy = makePolicy({ shown: true, current: true, dropDelay: 60000 })
            policy.shown = false

            policy.memoryPressure(false)
            verify(policy.keepLoaded)

            policy.current = false
            policy.memoryPressure(false)
            verify(!policy.keepLoaded)
        }

        function test_pressureAfterTheDropIsIgnored() {
            const policy = makePolicy({ shown: true, dropDelay: 60000 })
            policy.shown = false
            policy.memoryPressure(true)

            policy.memoryPressure(true)

            compare(policy.droppings, 1)
        }

        function test_aHeldDropKeepsTheUi() {
            const policy = makePolicy({ shown: true, held: true, dropDelay: 60000 })

            policy.shown = false
            policy.memoryPressure(true)

            verify(policy.keepLoaded)
            compare(policy.heldDrops, 1)
            compare(policy.droppings, 0)
        }

        function test_theHoldEndingRestartsTheDelay() {
            const policy = makePolicy({ shown: true, held: true, dropDelay: 60000 })
            policy.shown = false
            policy.memoryPressure(true)
            verify(!policy.d.timer.running)

            policy.held = false

            verify(policy.keepLoaded, "the delay starts over")
            verify(policy.d.timer.running)
        }

        function test_showingAgainBringsTheUiBack() {
            const policy = makePolicy({ shown: true, dropDelay: 60000 })
            policy.shown = false
            policy.memoryPressure(true)
            verify(!policy.keepLoaded)

            policy.shown = true

            verify(policy.keepLoaded)
        }
    }
}
