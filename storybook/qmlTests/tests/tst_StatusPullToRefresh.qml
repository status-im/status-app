import QtQuick
import QtTest

import StatusQ.Components

Item {
    id: root

    width: 400
    height: 600

    Component {
        id: viewComponent

        Flickable {
            id: view

            readonly property alias pullToRefresh: pullToRefresh
            property alias contentRectHeight: content.height

            anchors.fill: parent
            contentWidth: width
            contentHeight: content.height
            boundsBehavior: Flickable.StopAtBounds

            Rectangle {
                id: content
                width: view.width
                height: 2000
            }

            StatusPullToRefresh {
                id: pullToRefresh
                flickable: view
            }
        }
    }

    SignalSpy {
        id: refreshSpy
        signalName: "refreshRequested"
    }

    TestCase {
        name: "StatusPullToRefresh"
        when: windowShown

        function createView(properties = {}) {
            const view = createTemporaryObject(viewComponent, root, properties)
            verify(!!view)
            refreshSpy.clear()
            refreshSpy.target = view.pullToRefresh
            return view
        }

        function drag(view, distance, release = true) {
            const steps = 10
            const startY = distance > 0 ? 50 : view.height - 50
            mousePress(view, 200, startY)
            for (let i = 1; i <= steps; i++)
                mouseMove(view, 200, startY + distance * i / steps)
            if (release)
                mouseRelease(view, 200, startY + distance)
        }

        function test_pullPastTheThresholdAtTheTopRequestsARefresh() {
            const view = createView()

            drag(view, 400)

            compare(refreshSpy.count, 1)
        }

        function test_refreshIsRequestedOnReleaseOnly() {
            const view = createView()

            drag(view, 400, false)
            compare(refreshSpy.count, 0)
            verify(view.pullToRefresh.visible)

            mouseRelease(view, 200, 450)
            compare(refreshSpy.count, 1)
        }

        function test_shortPullRequestsNothing() {
            const view = createView()

            drag(view, 60)

            compare(refreshSpy.count, 0)
        }

        function test_contentDoesNotMoveWhilePulling() {
            const view = createView()

            drag(view, 400, false)
            compare(view.contentY, 0)
            compare(view.contentItem.y, 0)

            mouseRelease(view, 200, 450)
        }

        function test_dragAwayFromTheTopScrollsAndRequestsNothing() {
            const view = createView()
            view.contentY = 1000

            drag(view, 400)

            compare(refreshSpy.count, 0)
            verify(view.contentY < 1000)
        }

        function test_dragUpScrollsAndRequestsNothing() {
            const view = createView()

            drag(view, -400)

            compare(refreshSpy.count, 0)
            verify(view.contentY > 0)
        }

        function test_wheelScrolls() {
            const view = createView()

            mouseWheel(view, 200, 300, 0, -240)

            tryVerify(() => view.contentY > 0)
            compare(refreshSpy.count, 0)
        }

        function test_disabledRequestsNothingAndLeavesTheViewAsItWas() {
            const view = createView()
            view.pullToRefresh.enabled = false
            compare(view.boundsBehavior, Flickable.StopAtBounds)
            compare(view.flickableDirection, Flickable.AutoFlickDirection)

            drag(view, 400, false)
            compare(view.verticalOvershoot, 0)
            verify(!view.pullToRefresh.visible)

            mouseRelease(view, 200, 450)
            compare(refreshSpy.count, 0)
        }

        function test_disabledDuringAPullHidesTheIndicatorAndRequestsNothing() {
            const view = createView()
            drag(view, 400, false)
            verify(view.pullToRefresh.visible)

            view.pullToRefresh.enabled = false
            mouseRelease(view, 200, 450)

            tryCompare(view.pullToRefresh, "visible", false)
            compare(refreshSpy.count, 0)

            view.pullToRefresh.enabled = true
            compare(view.pullToRefresh.visible, false)
        }

        function test_viewDisabledDuringAPullHidesTheIndicatorAndRequestsNothing() {
            const view = createView()
            drag(view, 400, false)
            verify(view.pullToRefresh.visible)

            view.enabled = false
            mouseRelease(view, 200, 450)

            tryCompare(view.pullToRefresh, "visible", false)
            compare(refreshSpy.count, 0)

            view.enabled = true
            compare(view.pullToRefresh.visible, false)
        }

        function test_pullOnContentShorterThanTheViewRequestsARefresh() {
            const view = createView({ contentRectHeight: 100 })

            drag(view, 400)

            compare(refreshSpy.count, 1)
        }

        function test_pullOnContentAsTallAsTheViewRequestsARefresh() {
            const view = createView({ contentRectHeight: root.height })
            compare(view.contentHeight, view.height)

            drag(view, 400)

            compare(refreshSpy.count, 1)
        }

        function test_dragFromBelowTheTopThatPullsPastItRequestsARefresh() {
            const view = createView()
            view.contentY = 100

            drag(view, 500)

            compare(view.contentY, 0)
            compare(refreshSpy.count, 1)
        }

        function test_pullWhileRefreshingRequestsNothing() {
            const view = createView()
            view.pullToRefresh.refreshing = true

            drag(view, 400)

            compare(refreshSpy.count, 0)
        }

        function test_indicatorIsShownWhileRefreshing() {
            const view = createView()
            compare(view.pullToRefresh.visible, false)

            view.pullToRefresh.refreshing = true
            compare(view.pullToRefresh.visible, true)
            compare(view.pullToRefresh.parent, view)
            tryCompare(view.pullToRefresh, "opacity", 1)
            verify(view.pullToRefresh.y > 0)
            verify(view.pullToRefresh.y + view.pullToRefresh.height < view.height)

            view.pullToRefresh.refreshing = false
            tryCompare(view.pullToRefresh, "visible", false)
        }

        function test_indicatorIsShownWhileRefreshingWhenDisabled() {
            const view = createView()
            view.pullToRefresh.enabled = false

            view.pullToRefresh.refreshing = true

            compare(view.pullToRefresh.visible, true)
        }
    }
}
