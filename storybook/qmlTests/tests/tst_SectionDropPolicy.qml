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

        function test_comingBackBeforeTheDelayKeepsEverything() {
            const policy = makePolicy({ shown: true, dropDelay: 100 })

            policy.shown = false
            policy.shown = true
            wait(200) // longer than dropDelay: nothing may fire

            verify(policy.keepLoaded)
            compare(policy.droppings, 0)
        }

        function test_neverWhileShown() {
            const policy = makePolicy({ shown: true })

            policy.memoryPressure()
            wait(100)

            verify(policy.keepLoaded)
            compare(policy.droppings, 0)
        }

        function test_memoryPressureDropsAtOnceWhileNotShown() {
            const policy = makePolicy({ shown: true, dropDelay: 60000 })

            policy.shown = false
            policy.memoryPressure()

            verify(!policy.keepLoaded)
            compare(policy.droppings, 1)
        }

        function test_memoryPressureAfterTheDropIsIgnored() {
            const policy = makePolicy({ shown: true, dropDelay: 60000 })
            policy.shown = false
            policy.memoryPressure()

            policy.memoryPressure()

            compare(policy.droppings, 1)
        }

        function test_aHeldDropKeepsTheUi() {
            const policy = makePolicy({ shown: true, held: true, dropDelay: 60000 })

            policy.shown = false
            policy.memoryPressure()

            verify(policy.keepLoaded)
            compare(policy.heldDrops, 1)
            compare(policy.droppings, 0)
        }

        function test_theHoldEndingRestartsTheDelay() {
            const policy = makePolicy({ shown: true, held: true, dropDelay: 60000 })
            policy.shown = false
            policy.memoryPressure()
            policy.dropDelay = 50

            policy.held = false
            verify(policy.keepLoaded, "the delay starts over")

            tryVerify(() => !policy.keepLoaded)
        }

        function test_showingAgainBringsTheUiBack() {
            const policy = makePolicy({ shown: true })
            policy.shown = false
            tryVerify(() => !policy.keepLoaded)

            policy.shown = true

            verify(policy.keepLoaded)
        }
    }
}
