import QtQuick
import QtTest

import AppLayouts.Communities.helpers
import AppLayouts.Communities.stores

// A RosterHolder pairs every acquire of a community roster with exactly one
// release: on deactivation, on a community change and on destruction.
Item {
    id: root

    CommunitiesStore {
        id: store
    }

    Component {
        id: holderComponent

        RosterHolder {
            communitiesStore: store
            communityId: "c1"
        }
    }

    SignalSpy {
        id: acquiredSpy
        target: store
        signalName: "communityRosterAcquired"
    }

    SignalSpy {
        id: releasedSpy
        target: store
        signalName: "communityRosterReleased"
    }

    TestCase {
        name: "RosterHolder"

        function init() {
            store.rosterHolds = ({})
            acquiredSpy.clear()
            releasedSpy.clear()
        }

        function holds(communityId) {
            return store.rosterHolds[communityId] ?? 0
        }

        function test_acquiresOnCreationReleasesOnDestruction() {
            const holder = createTemporaryObject(holderComponent, root)
            verify(holder.holding)
            compare(holds("c1"), 1)
            compare(acquiredSpy.count, 1)

            holder.destroy()
            tryCompare(releasedSpy, "count", 1)
            compare(holds("c1"), 0)
        }

        function test_inactiveHolderDoesNotAcquire() {
            const holder = createTemporaryObject(holderComponent, root, { active: false })
            verify(!holder.holding)
            compare(acquiredSpy.count, 0)

            holder.active = true
            compare(holds("c1"), 1)

            holder.active = false
            verify(!holder.holding)
            compare(holds("c1"), 0)
            compare(releasedSpy.count, 1)
        }

        function test_repeatedActivationKeepsOneHold() {
            const holder = createTemporaryObject(holderComponent, root)
            holder.active = true
            holder.active = false
            holder.active = true
            compare(holds("c1"), 1)
            compare(acquiredSpy.count, 2)
            compare(releasedSpy.count, 1)
        }

        function test_communityChangeMovesTheHold() {
            const holder = createTemporaryObject(holderComponent, root)
            holder.communityId = "c2"
            compare(holds("c1"), 0)
            compare(holds("c2"), 1)

            holder.communityId = ""
            verify(!holder.holding)
            compare(holds("c2"), 0)
        }

        function test_onlyTheCommunityIdPicksTheRoster() {
            const holder = createTemporaryObject(holderComponent, root)
            compare(holder.key, undefined)
        }

        function test_twoHoldersCountTwice() {
            const first = createTemporaryObject(holderComponent, root)
            const second = createTemporaryObject(holderComponent, root)
            compare(holds("c1"), 2)

            first.active = false
            compare(holds("c1"), 1)
            verify(second.holding)
        }
    }
}
