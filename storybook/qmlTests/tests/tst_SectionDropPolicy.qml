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
            inBackground: false
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
            verify(policy.dropPending)
            policy.shown = true

            verify(!policy.dropPending)
            verify(policy.keepLoaded)
        }

        // The app in the background with this section current: it is what
        // the user comes back to.
        function test_theCurrentSectionNeverDropsOnTheDelay() {
            const policy = makePolicy({ shown: true, current: true })

            policy.shown = false

            verify(!policy.dropPending)
            verify(policy.keepLoaded)
        }

        function test_leavingTheCurrentSectionStartsTheDelay() {
            const policy = makePolicy({ shown: true, current: true, dropDelay: 60000 })
            policy.shown = false

            policy.current = false

            verify(policy.dropPending)
        }

        function test_neverWhileShown() {
            const policy = makePolicy({ shown: true, current: true })

            policy.memoryPressure()

            verify(policy.keepLoaded)
            compare(policy.droppings, 0)
        }

        // Pressure queued while frozen (before API 34) is handled on the way
        // back, before the app is in front again: the current section stays.
        function test_pressureWhileInTheBackgroundSparesTheCurrentSection() {
            const policy = makePolicy({ shown: true, current: true, dropDelay: 60000 })
            policy.shown = false
            policy.inBackground = true

            policy.memoryPressure()

            verify(policy.keepLoaded)
            compare(policy.droppings, 0)
        }

        function test_pressureDropsASectionTheUserLeft() {
            const policy = makePolicy({ shown: true, dropDelay: 60000 })
            policy.shown = false

            policy.memoryPressure()

            verify(!policy.keepLoaded)
            compare(policy.droppings, 1)
        }

        // A system sheet or picker on top (Inactive): not shown, still current.
        function test_pressureUnderASystemSheetSparesTheCurrentSection() {
            const policy = makePolicy({ shown: true, current: true, dropDelay: 60000 })
            policy.shown = false

            policy.memoryPressure()

            verify(policy.keepLoaded)
            compare(policy.droppings, 0)
        }

        function test_pressureAfterTheDropIsIgnored() {
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
            verify(!policy.dropPending)

            policy.held = false

            verify(policy.keepLoaded, "the delay starts over")
            verify(policy.dropPending)
        }

        // A hold that comes and goes while the delay runs (a dApp polling)
        // must not push the drop out forever.
        function test_aHoldTogglingBeforeTheDropKeepsTheRunningDelay() {
            const policy = makePolicy({ shown: true, dropDelay: 200 })
            const toggler = createTemporaryQmlObject(
                "import QtQuick; Timer { interval: 40; repeat: true; running: true }", root)
            toggler.triggered.connect(() => { policy.held = true; policy.held = false })

            policy.shown = false

            tryVerify(() => !policy.keepLoaded, 1000)
        }

        function test_aDeferredDropRestartsWhenTheHoldEnds() {
            const policy = makePolicy({ shown: true, held: true, dropDelay: 60000 })
            policy.shown = false
            policy.memoryPressure()

            policy.held = false
            policy.held = true
            policy.held = false

            verify(policy.dropPending, "one restart for the deferred drop")
            compare(policy.heldDrops, 1)
        }

        // ---- the app going to the background ----------------------------------
        //
        // Android stops the event loop and then freezes the process: what is
        // to go goes on the way out, and the delay only runs in the app.

        function test_goingToTheBackgroundDropsASectionTheUserLeft() {
            const policy = makePolicy({ shown: true, current: true, dropDelay: 60000 })
            policy.shown = false
            policy.current = false

            policy.inBackground = true

            verify(!policy.keepLoaded)
            compare(policy.droppings, 1)
        }

        function test_goingToTheBackgroundSparesTheCurrentSection() {
            const policy = makePolicy({ shown: true, current: true, dropDelay: 60000 })
            policy.shown = false

            policy.inBackground = true

            verify(policy.keepLoaded)
            compare(policy.droppings, 0)
        }

        function test_goingToTheBackgroundSparesAHeldSection() {
            const policy = makePolicy({ shown: true, current: true, held: true, dropDelay: 60000 })
            policy.shown = false
            policy.current = false

            policy.inBackground = true

            verify(policy.keepLoaded)
            compare(policy.droppings, 0)
        }

        function test_theDelayDoesNotRunInTheBackground() {
            const policy = makePolicy({ shown: true, current: true, held: true, dropDelay: 60000 })
            policy.shown = false
            policy.current = false
            verify(policy.dropPending)

            policy.inBackground = true
            verify(!policy.dropPending)

            policy.held = false
            verify(!policy.dropPending, "not even when a hold ends")
        }

        function test_returningRestartsTheDelay() {
            const policy = makePolicy({ shown: true, current: true, held: true, dropDelay: 60000 })
            policy.shown = false
            policy.current = false
            policy.inBackground = true
            policy.held = false

            policy.inBackground = false

            verify(policy.keepLoaded)
            verify(policy.dropPending)
        }

        // a background trim handled on return finds the current section spared
        function test_aBackgroundTrimAfterReturningSparesTheCurrentSection() {
            const policy = makePolicy({ shown: true, current: true, dropDelay: 60000 })
            policy.inBackground = true
            policy.shown = false
            policy.inBackground = false

            policy.memoryPressure()

            verify(policy.keepLoaded)
        }

        function test_showingAgainBringsTheUiBack() {
            const policy = makePolicy({ shown: true, dropDelay: 60000 })
            policy.shown = false
            policy.memoryPressure()
            verify(!policy.keepLoaded)

            policy.shown = true

            verify(policy.keepLoaded)
        }
    }
}
