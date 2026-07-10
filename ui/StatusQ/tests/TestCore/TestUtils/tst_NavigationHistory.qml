import QtQuick
import QtTest

import StatusQ.Core.Utils

Item {
    id: root

    Component {
        id: testComponent
        NavigationHistory {}
    }

    TestCase {
        name: "NavigationHistory"

        function test_initial_state() {
            const h = createTemporaryObject(testComponent, root)
            verify(!!h)
            compare(h.canGoBack, false)
            compare(h.back(), "")
        }

        function test_record_and_back() {
            const h = createTemporaryObject(testComponent, root)
            h.record("A")
            h.record("B")
            h.record("C")
            compare(h.canGoBack, true)
            compare(h.peek(), "C")
            compare(h.back(), "C")
            compare(h.peek(), "B")
            compare(h.back(), "B")
            compare(h.back(), "A")
            compare(h.canGoBack, false)
            compare(h.back(), "")
            compare(h.peek(), "")
        }

        function test_consecutive_dedup() {
            const h = createTemporaryObject(testComponent, root)
            h.record("A")
            h.record("A")
            h.record("A")
            compare(h.canGoBack, true)
            compare(h.back(), "A")
            compare(h.canGoBack, false)
        }

        function test_non_consecutive_duplicates_kept() {
            const h = createTemporaryObject(testComponent, root)
            h.record("A")
            h.record("B")
            h.record("A")
            compare(h.back(), "A")
            compare(h.back(), "B")
            compare(h.back(), "A")
            compare(h.canGoBack, false)
        }

        function test_record_ignores_empty_token() {
            const h = createTemporaryObject(testComponent, root)
            h.record("")
            h.record(null)
            h.record(undefined)
            compare(h.canGoBack, false)
        }

        function test_maxDepth_eviction() {
            const h = createTemporaryObject(testComponent, root)
            h.maxDepth = 3
            h.record("A")
            h.record("B")
            h.record("C")
            h.record("D") // evicts A
            compare(h.back(), "D")
            compare(h.back(), "C")
            compare(h.back(), "B")
            compare(h.canGoBack, false)
        }

        function test_clear() {
            const h = createTemporaryObject(testComponent, root)
            h.record("A")
            h.record("B")
            h.clear()
            compare(h.canGoBack, false)
            compare(h.back(), "")
        }

        function test_maxDepth_reduction_trims_existing_entries() {
            const h = createTemporaryObject(testComponent, root)
            h.record("A")
            h.record("B")
            h.record("C")
            h.record("D")
            compare(h.canGoBack, true)
            h.maxDepth = 2  // should evict A and B
            compare(h.back(), "D")
            compare(h.back(), "C")
            compare(h.canGoBack, false)
        }
    }
}
