import QtQuick
import QtTest

import AppLayouts.Browser.adapters

import "helpers"

/// A View whose render process dies shows the crashed page and never reloads
/// itself. The fake adapter is required: QmlTests links no Qt::WebView.
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
        name: "BrowserCrashRecovery"
        when: windowShown

        function makeView(props) {
            const view = createTemporaryObject(lazyViewComponent, root, props ?? {})
            verify(!!view)
            view.ensureLoaded()
            const fake = view.adapterItem
            verify(!!fake, "the fake adapter must be loaded")
            return { view: view, fake: fake }
        }

        function test_aCrashShowsTheCrashedPageAndReloadsNothing() {
            const { view, fake } = makeView()

            fake.simulateCrash()

            verify(view.crashed)
            compare(fake.reloadCalls, 0, "reloading is the user's call")
        }

        // Dies on a timer, loads fine in between: any self-issued reload loops.
        function test_repeatedCrashesNeverReload() {
            const { view, fake } = makeView()

            fake.simulateCrash()
            fake.htmlPageLoaded = true
            fake.simulateCrash()
            fake.simulateCrash()

            verify(view.crashed)
            compare(fake.reloadCalls, 0)
        }

        function test_aStartingLoadClearsTheCrashedPage() {
            const { view, fake } = makeView()

            fake.simulateCrash()
            verify(view.crashed)

            fake.loading = true

            verify(!view.crashed, "whatever asked for the navigation")
        }

        // Clearing on a successful load instead would strand the user on the
        // crashed page whenever the next navigation fails, hiding the engine's
        // own error page behind the overlay.
        function test_aFailedNavigationAlsoClearsTheCrashedPage() {
            const { view, fake } = makeView()

            fake.simulateCrash()
            fake.loading = true
            fake.loading = false

            verify(!view.crashed)
        }

        function test_manualReloadReachesTheAdapter() {
            const { view, fake } = makeView()

            fake.simulateCrash()
            view.reload()

            compare(fake.reloadCalls, 1)
        }

        // A Backend that revives its view brings the renderer back itself.
        function test_aRendererTheBackendRevivesShowsNothing() {
            const { view, fake } = makeView()

            fake.simulateKill(true)
            fake.simulateCrash(true)

            verify(!view.crashed)
            compare(fake.reloadCalls, 0)
        }

        // The Backend decided on its own visibility when the renderer died.
        function test_aHiddenRendererTheBackendLeftDownShowsTheCrashedPage() {
            const { view, fake } = makeView()
            view.visible = false

            fake.simulateCrash(false)
            view.visible = true

            verify(view.crashed)
            compare(fake.reloadCalls, 0)
        }

        // Repeated kills: the Backend gives up, the page is the user's to reload.
        function test_aKillTheBackendLeftDownShowsTheCrashedPage() {
            const { view, fake } = makeView()

            fake.simulateKill(false)

            verify(view.crashed)
            compare(fake.reloadCalls, 0)
        }

        function test_theBackendStatusReachesListenersUnchanged() {
            const { view, fake } = makeView()
            const statuses = []
            view.renderProcessTerminated.connect((status, exitCode, willRevive) =>
                statuses.push([status, exitCode, willRevive]))

            fake.simulateCrash(true)

            compare(statuses, [[2, 133, true]])
        }

        // No Tab left to show a crashed page in (ADR 0006 §6).
        function test_retainedViewsAreLeftAlone() {
            const { view, fake } = makeView({ retained: true })

            fake.simulateCrash()

            verify(!view.crashed)
            compare(fake.reloadCalls, 0)
        }
    }
}
