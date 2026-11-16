import QtQuick
import QtTest

import AppLayouts.Browser.adapters

import "helpers"

/// Drop (CONTEXT): a Tab gives its Backend back and keeps everything else; the
/// next load brings the page back with its history.
Item {
    id: root

    width: 400
    height: 400

    Component {
        id: lazyViewComponent

        LazyWebViewAdapter {
            adapterPath: Qt.resolvedUrl("helpers/FakeWebViewAdapter.qml")

            profileParams: ProfileParams {
                userId: "user-1"
                userAgent: ""
                scripts: []
                offTheRecord: false
            }
            bookmarksStore: null
            localAccountSettings: QtObject {}
            webChannel: null
            devToolsEnabled: false
            enableJsLogs: false
        }
    }

    TestCase {
        name: "BrowserTabDrop"
        when: windowShown

        function makeLoadedView() {
            const view = createTemporaryObject(lazyViewComponent, root)
            verify(!!view)
            view.loadUrl("https://status.app/")
            const fake = view.adapterItem
            verify(!!fake)
            fake.title = "Status"
            fake.htmlPageLoaded = true
            return { view: view, fake: fake }
        }

        function test_dropDestroysTheBackendAndKeepsTheTab() {
            const { view } = makeLoadedView()

            view.drop()

            verify(view.adapterItem === null)
            compare(view.title, "Status")
            compare(String(view.url), "https://status.app/")
            verify(!view.htmlPageLoaded, "nothing on screen until it loads again")
        }

        function test_theNextLoadRestoresTheHistory() {
            const { view, fake } = makeLoadedView()
            fake.savedState = "history"

            view.drop()
            view.ensureLoaded()

            const revived = view.adapterItem
            verify(!!revived)
            compare(revived.restoredStates, ["history"])
            compare(String(revived.url), "https://status.app/")
        }

        function test_aPendingStateIsUsedOnce() {
            const { view, fake } = makeLoadedView()
            fake.savedState = "history"
            view.drop()
            view.ensureLoaded()
            view.adapterItem.savedState = null

            view.drop()
            view.ensureLoaded()

            compare(view.adapterItem.restoredStates, [])
        }

        function test_aStateSetBeforeTheFirstLoadIsRestored() {
            const view = createTemporaryObject(lazyViewComponent, root)
            view.url = "https://status.app/"
            view.setPendingState("history")

            view.ensureLoaded()

            compare(view.adapterItem.restoredStates, ["history"])
        }

        function test_saveStatePrefersTheLiveBackend() {
            const { view, fake } = makeLoadedView()
            view.setPendingState("old")
            compare(view.saveState(), "old", "nothing captured yet")

            fake.savedState = "new"
            compare(view.saveState(), "new")
        }

        function test_terminateRendererReachesTheBackend() {
            const { view, fake } = makeLoadedView()
            view.terminateRenderer()
            compare(fake.terminateRendererCalls, 1)
        }

        function test_droppingAnUnloadedTabDoesNothing() {
            const view = createTemporaryObject(lazyViewComponent, root)
            view.drop()
            verify(view.adapterItem === null)
        }
    }
}
