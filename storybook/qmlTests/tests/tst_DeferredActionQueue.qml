import QtQuick
import QtTest

import mainui

Item {
    id: root

    Component {
        id: queueComponent

        DeferredActionQueue {}
    }

    TestCase {
        name: "DeferredActionQueue"

        function createQueue(blocked) {
            return createTemporaryObject(queueComponent, root, { blocked })
        }

        function test_runsImmediatelyWhenUnblocked() {
            const queue = createQueue(false)
            const calls = []
            queue.schedule("a", () => calls.push("a"))
            compare(calls, ["a"])
            compare(queue.pendingCount, 0)
        }

        function test_holdsWhileBlockedAndRunsInOrderOnUnblock() {
            const queue = createQueue(true)
            const calls = []
            queue.schedule("a", () => calls.push("a"))
            queue.schedule("b", () => calls.push("b"))
            compare(calls, [])
            compare(queue.pendingCount, 2)

            queue.blocked = false
            compare(calls, ["a", "b"])
            compare(queue.pendingCount, 0)
        }

        function test_rescheduledKeyReplacesActionAndKeepsPlace() {
            const queue = createQueue(true)
            const calls = []
            queue.schedule("a", () => calls.push("a1"))
            queue.schedule("b", () => calls.push("b"))
            queue.schedule("a", () => calls.push("a2"))
            compare(queue.pendingCount, 2)

            queue.blocked = false
            compare(calls, ["a2", "b"])
        }

        function test_actionReblockingKeepsRestHeld() {
            const queue = createQueue(true)
            const calls = []
            queue.schedule("a", () => { calls.push("a"); queue.blocked = true })
            queue.schedule("b", () => calls.push("b"))

            queue.blocked = false
            compare(calls, ["a"])
            compare(queue.pendingCount, 1)

            queue.blocked = false
            compare(calls, ["a", "b"])
        }
    }
}
