import QtQuick
import QtTest

import StatusQ.Core

import utils

/// One memory release pass once dropped UI is gone.
Item {
    id: root

    Component {
        id: schedulerComponent

        MemoryReleaseScheduler {
            property int passes: 0

            releaseContext: null
            appState: Qt.ApplicationActive

            onReleased: passes++
        }
    }

    TestCase {
        name: "MemoryReleaseScheduler"

        function makeScheduler() {
            const scheduler = createTemporaryObject(schedulerComponent, root)
            verify(!!scheduler)
            return scheduler
        }

        function test_aBurstInFrontIsOnePassLater() {
            const scheduler = makeScheduler()
            compare(scheduler.releaseDelay, 2000)
            scheduler.releaseDelay = 50

            scheduler.request()
            scheduler.request()
            scheduler.request()
            compare(scheduler.passes, 0, "nothing at once")

            tryCompare(scheduler, "passes", 1)
            verify(!scheduler.passPending)
        }

        function test_aPendingPassRunsOnTheWayToTheBackground() {
            const scheduler = makeScheduler()

            scheduler.request()
            verify(scheduler.passPending)

            SystemUtils.enteringBackground()

            compare(scheduler.passes, 1, "synchronously")
            verify(!scheduler.passPending)
            verify(scheduler.appInBackground)
        }

        function test_theWayToTheBackgroundWithNothingPendingRunsNoPass() {
            const scheduler = makeScheduler()

            SystemUtils.enteringBackground()

            compare(scheduler.passes, 0)
            verify(scheduler.appInBackground)
        }

        function test_aRequestInTheBackgroundWaitsForTheWayOut() {
            const scheduler = makeScheduler()
            SystemUtils.enteringBackground()

            scheduler.request()
            verify(!scheduler.passPending)
            compare(scheduler.passes, 0)

            SystemUtils.enteringBackground()
            compare(scheduler.passes, 1)
        }

        function test_aRequestInTheBackgroundRunsInFrontOnReturn() {
            const scheduler = makeScheduler()
            scheduler.appState = Qt.ApplicationSuspended
            SystemUtils.enteringBackground()
            scheduler.request()

            scheduler.appState = Qt.ApplicationActive

            verify(scheduler.passPending)
            compare(scheduler.passes, 0)

            SystemUtils.enteringBackground()
            compare(scheduler.passes, 1, "one pass, on the way out")
        }

        function test_inactiveIsInFront() {
            const scheduler = makeScheduler()
            scheduler.appState = Qt.ApplicationSuspended
            SystemUtils.enteringBackground()
            verify(scheduler.appInBackground)

            scheduler.appState = Qt.ApplicationInactive

            verify(!scheduler.appInBackground)
            scheduler.request()
            verify(scheduler.passPending, "a pass in front comes later")
        }

        function test_activeIsInFront() {
            const scheduler = makeScheduler()
            scheduler.appState = Qt.ApplicationHidden
            SystemUtils.enteringBackground()

            scheduler.appState = Qt.ApplicationActive

            verify(!scheduler.appInBackground)
        }
    }
}
