import QtQuick
import QtTest

import StatusQ.Core.Utils

Item {
    id: root

    // Test helper: applies navigateRequested back to currentKey, the way a real
    // section's setter eventually would. `applyNavigation` lets a test choose to
    // apply it synchronously (default) or defer it (to model the async case).
    Component {
        id: testComponent
        SubsectionNavigationHistory {
            property var lastRequested: undefined
            property bool applyNavigation: true
            onNavigateRequested: (key) => {
                lastRequested = key
                if (applyNavigation)
                    currentKey = key
            }
        }
    }

    TestCase {
        name: "SubsectionNavigationHistory"

        function make(props) {
            const h = createTemporaryObject(testComponent, root, props)
            verify(!!h)
            return h
        }

        function test_initial_state() {
            const h = make({ currentKey: "A" })
            compare(h.canGoBack, false)
            compare(h.tryGoBack(), false)
        }

        function test_records_previous_on_change() {
            const h = make({ currentKey: "A" })
            h.currentKey = "B" // records A
            compare(h.canGoBack, true)
            h.currentKey = "C" // records B
            compare(h.canGoBack, true)
        }

        function test_back_navigates_and_does_not_rerecord() {
            const h = make({ currentKey: "A" })
            h.currentKey = "B" // records A
            h.currentKey = "C" // records B
            // Back to B (applies synchronously via the test handler).
            compare(h.tryGoBack(), true)
            compare(h.lastRequested, "B")
            compare(h.currentKey, "B")
            // The settling of our own back navigation must NOT have been recorded.
            compare(h.tryGoBack(), true)
            compare(h.lastRequested, "A")
            compare(h.currentKey, "A")
            compare(h.canGoBack, false)
        }

        function test_async_back_guard() {
            // Model the async setter: navigateRequested does not immediately
            // change currentKey; the change arrives later. The guard must still
            // suppress the re-record.
            const h = make({ currentKey: "A", applyNavigation: false })
            h.currentKey = "B" // records A
            h.currentKey = "C" // records B
            compare(h.tryGoBack(), true)
            compare(h.lastRequested, "B")
            compare(h.currentKey, "C") // not applied yet
            // Now the async change lands:
            h.currentKey = "B"
            // It was the pending back target, so nothing new is recorded; A remains.
            h.applyNavigation = true
            compare(h.tryGoBack(), true)
            compare(h.lastRequested, "A")
            compare(h.canGoBack, false)
        }

        function test_unrelated_change_cancels_guard() {
            const h = make({ currentKey: "A", applyNavigation: false })
            h.currentKey = "B" // records A
            h.currentKey = "C" // records B
            h.tryGoBack()      // pending target = B, not yet applied
            // User navigates somewhere else instead of the back settling:
            h.currentKey = "D" // cancels guard, records C
            h.applyNavigation = true
            // History should now be A, B, C (B was the popped one; C recorded on D).
            compare(h.tryGoBack(), true)
            compare(h.lastRequested, "C")
        }

        function test_stale_token_skipped_via_validateFn() {
            const h = make({ currentKey: "A" })
            h.validateFn = (token) => token !== "B" // B is "gone"
            h.currentKey = "B" // records A
            h.currentKey = "C" // records B
            // Top of stack is B (invalid) → skipped; pops A.
            compare(h.tryGoBack(), true)
            compare(h.lastRequested, "A")
            compare(h.canGoBack, false)
        }

        function test_clear() {
            const h = make({ currentKey: "A" })
            h.currentKey = "B"
            h.currentKey = "C"
            h.clear()
            compare(h.canGoBack, false)
            compare(h.tryGoBack(), false)
        }

        function test_dropLeaf_discards_dismissed_subsection() {
            // list -> sub1 -> back(list) -> sub2 : sub1 was dismissed via Back,
            // so it must NOT be retraceable.
            const h = make({ currentKey: "" })
            h.currentKey = "sub1"   // open sub1 (prev "" not recorded)
            h.dropLeaf()            // Back to list dismisses sub1
            h.currentKey = "sub2"   // open sub2 — sub1 must not be recorded
            compare(h.canGoBack, false)
            compare(h.tryGoBack(), false)
        }

        function test_without_dropLeaf_previous_is_recorded() {
            // Contrast: without the Back-to-list dismissal, switching does record.
            const h = make({ currentKey: "" })
            h.currentKey = "sub1"
            h.currentKey = "sub2"   // records sub1
            compare(h.canGoBack, true)
            compare(h.tryGoBack(), true)
            compare(h.lastRequested, "sub1")
        }

        function test_dropLeaf_keeps_earlier_history() {
            // X active, sub1 opened over it (records X), back-to-list dismisses
            // sub1, but X remains retraceable.
            const h = make({ currentKey: "X" })
            h.currentKey = "sub1"   // records X
            h.dropLeaf()            // dismiss sub1
            compare(h.tryGoBack(), true)
            compare(h.lastRequested, "X")
            compare(h.canGoBack, false)
        }

        function test_empty_keys_ignored() {
            const h = make({ currentKey: "" })
            h.currentKey = "A"  // previous was "" → not recorded
            compare(h.canGoBack, false)
        }
    }
}
