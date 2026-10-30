import QtQuick
import QtTest

import StatusQ.Core.Utils

// A ResourceHolder pairs every acquire request with exactly one release
// request: on deactivation, on a key change and on destruction.
Item {
    id: root

    property var holds: ({})

    function hold(key, delta) {
        const next = Object.assign({}, holds)
        next[key] = (next[key] ?? 0) + delta
        holds = next
    }

    Component {
        id: holderComponent

        ResourceHolder {
            key: "k1"

            onAcquireRequested: key => root.hold(key, 1)
            onReleaseRequested: key => root.hold(key, -1)
        }
    }

    TestCase {
        name: "ResourceHolder"

        function init() {
            root.holds = ({})
        }

        function holds(key) {
            return root.holds[key] ?? 0
        }

        function test_acquiresOnCreationReleasesOnDestruction() {
            const holder = createTemporaryObject(holderComponent, root)
            verify(holder.holding)
            compare(holds("k1"), 1)

            const released = createTemporaryObject(signalSpy, root, { target: holder, signalName: "releaseRequested" })
            holder.destroy()
            tryCompare(released, "count", 1)
            compare(released.signalArguments[0][0], "k1")
            compare(holds("k1"), 0)
        }

        function test_inactiveHolderDoesNotAcquire() {
            const holder = createTemporaryObject(holderComponent, root, { active: false })
            verify(!holder.holding)
            compare(holds("k1"), 0)

            holder.active = true
            verify(holder.holding)
            compare(holds("k1"), 1)

            holder.active = false
            verify(!holder.holding)
            compare(holds("k1"), 0)
        }

        function test_repeatedActivationKeepsOneHold() {
            const holder = createTemporaryObject(holderComponent, root)
            const acquired = createTemporaryObject(signalSpy, root, { target: holder, signalName: "acquireRequested" })
            const released = createTemporaryObject(signalSpy, root, { target: holder, signalName: "releaseRequested" })
            holder.active = true
            holder.active = false
            holder.active = true
            compare(holds("k1"), 1)
            compare(acquired.count, 1)
            compare(released.count, 1)
        }

        function test_keyChangeMovesTheHold() {
            const holder = createTemporaryObject(holderComponent, root)
            holder.key = "k2"
            compare(holds("k1"), 0)
            compare(holds("k2"), 1)

            holder.key = ""
            verify(!holder.holding)
            compare(holds("k2"), 0)
        }

        function test_emptyKeyHoldsNothing() {
            const holder = createTemporaryObject(holderComponent, root, { key: "" })
            verify(!holder.holding)
            compare(Object.keys(root.holds).length, 0)
        }

        function test_keyChangeWhileInactiveHoldsNothing() {
            const holder = createTemporaryObject(holderComponent, root, { active: false })
            const acquired = createTemporaryObject(signalSpy, root, { target: holder, signalName: "acquireRequested" })
            const released = createTemporaryObject(signalSpy, root, { target: holder, signalName: "releaseRequested" })
            holder.key = "k2"
            compare(acquired.count, 0)
            compare(released.count, 0)

            holder.active = true
            compare(acquired.count, 1)
            compare(acquired.signalArguments[0][0], "k2")
            compare(holds("k1"), 0)
            compare(holds("k2"), 1)
        }

        function test_releaseHandlerChangingTheKeyAcquiresOnce() {
            const holder = createTemporaryObject(holderComponent, root)
            holder.releaseRequested.connect(key => {
                if (key === "k1")
                    holder.key = "k3"
            })
            const acquired = createTemporaryObject(signalSpy, root, { target: holder, signalName: "acquireRequested" })
            holder.key = "k2"
            compare(acquired.count, 1)
            compare(holds("k1"), 0)
            compare(holds("k2"), 0)
            compare(holds("k3"), 1)
            verify(holder.holding)

            holder.key = ""
            compare(holds("k3"), 0)
        }

        function test_releaseHandlerBouncingBackToTheKeyAcquiresOnce() {
            const holder = createTemporaryObject(holderComponent, root)
            holder.releaseRequested.connect(key => {
                if (key === "k1") {
                    holder.key = "k3"
                    holder.key = "k2"
                }
            })
            const acquired = createTemporaryObject(signalSpy, root, { target: holder, signalName: "acquireRequested" })
            const released = createTemporaryObject(signalSpy, root, { target: holder, signalName: "releaseRequested" })
            holder.key = "k2"
            compare(holds("k1"), 0)
            compare(holds("k2"), 1)
            compare(holds("k3"), 0)
            compare(acquired.count, 2)
            compare(released.count, 2)
            verify(holder.holding)

            holder.destroy()
            tryCompare(released, "count", 3)
            compare(released.signalArguments[2][0], "k2")
            compare(holds("k2"), 0)
        }

        function test_releaseHandlerDeactivatingHoldsNothing() {
            const holder = createTemporaryObject(holderComponent, root)
            holder.releaseRequested.connect(() => holder.active = false)
            const acquired = createTemporaryObject(signalSpy, root, { target: holder, signalName: "acquireRequested" })
            holder.key = "k2"
            compare(acquired.count, 0)
            compare(holds("k1"), 0)
            compare(holds("k2"), 0)
            verify(!holder.holding)
        }

        function test_holdingHandlerDeactivatingReleasesAfterAcquire() {
            const holder = createTemporaryObject(holderComponent, root, { active: false })
            const events = []
            holder.acquireRequested.connect(key => events.push("acquire " + key))
            holder.releaseRequested.connect(key => events.push("release " + key))
            holder.holdingChanged.connect(() => {
                events.push("holding " + holder.holding)
                if (holder.holding)
                    holder.active = false
            })
            holder.active = true
            compare(events, ["acquire k1", "holding true", "release k1", "holding false"])
            compare(holds("k1"), 0)
            verify(!holder.holding)
        }

        function test_holdingHandlerChangingTheKeyMovesTheHold() {
            const holder = createTemporaryObject(holderComponent, root, { active: false })
            const events = []
            holder.acquireRequested.connect(key => events.push("acquire " + key))
            holder.releaseRequested.connect(key => events.push("release " + key))
            holder.holdingChanged.connect(() => {
                if (holder.holding && holder.key === "k1")
                    holder.key = "k2"
            })
            holder.active = true
            compare(events, ["acquire k1", "release k1", "acquire k2"])
            compare(holds("k1"), 0)
            compare(holds("k2"), 1)
            verify(holder.holding)

            holder.key = ""
            compare(holds("k2"), 0)
            verify(!holder.holding)
        }

        function test_releaseHandlerChangingTheKeyOnDestructionAcquiresNothing() {
            const holder = createTemporaryObject(holderComponent, root)
            const acquired = createTemporaryObject(signalSpy, root, { target: holder, signalName: "acquireRequested" })
            const released = createTemporaryObject(signalSpy, root, { target: holder, signalName: "releaseRequested" })
            holder.releaseRequested.connect(() => holder.key = "k2")
            holder.destroy()
            tryCompare(released, "count", 1)
            compare(acquired.count, 0)
            compare(holds("k1"), 0)
            compare(holds("k2"), 0)
        }

        function test_acquireHandlerDeactivatingReleasesAfterAcquire() {
            const holder = createTemporaryObject(holderComponent, root, { active: false })
            const events = []
            holder.acquireRequested.connect(key => {
                events.push("acquire " + key)
                holder.active = false
            })
            holder.releaseRequested.connect(key => events.push("release " + key))
            const holdingChanged = createTemporaryObject(signalSpy, root, { target: holder, signalName: "holdingChanged" })
            holder.active = true
            compare(events, ["acquire k1", "release k1"])
            compare(holds("k1"), 0)
            verify(!holder.holding)
            compare(holdingChanged.count, 0)
        }

        function test_acquireHandlerChangingTheKeyMovesTheHold() {
            const holder = createTemporaryObject(holderComponent, root, { active: false })
            const events = []
            holder.acquireRequested.connect(key => {
                events.push("acquire " + key)
                if (key === "k1")
                    holder.key = "k2"
            })
            holder.releaseRequested.connect(key => events.push("release " + key))
            holder.active = true
            compare(events, ["acquire k1", "release k1", "acquire k2"])
            compare(holds("k1"), 0)
            compare(holds("k2"), 1)
            verify(holder.holding)

            holder.key = ""
            compare(holds("k2"), 0)
            verify(!holder.holding)
        }

        function test_holdingInsideTheHandlers() {
            const holder = createTemporaryObject(holderComponent, root, { active: false })
            const seen = []
            holder.acquireRequested.connect(() => seen.push("acquire " + holder.holding))
            holder.releaseRequested.connect(() => seen.push("release " + holder.holding))
            holder.active = true
            holder.active = false
            compare(seen, ["acquire false", "release true"])
        }

        function test_twoHoldersCountTwice() {
            const first = createTemporaryObject(holderComponent, root)
            const second = createTemporaryObject(holderComponent, root)
            compare(holds("k1"), 2)

            first.active = false
            compare(holds("k1"), 1)
            verify(second.holding)
        }
    }

    Component {
        id: signalSpy

        SignalSpy {}
    }
}
