import QtQuick
import QtTest

import AppLayouts.Browser.adapters

import "helpers"

/**
 * A View whose render process dies shows the crashed page and never reloads
 * itself. The fake adapter is required: QmlTests links no Qt::WebView.
 */
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
            localAccountSensitiveSettings: QtObject {}
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

        function test_navigationClearsTheCrashedPage() {
            const { view, fake } = makeView()

            fake.simulateCrash()
            verify(view.crashed)

            view.loadUrl("https://example.org")

            verify(!view.crashed, "navigating away puts the Web View back on screen")
            compare(fake.reloadCalls, 0, "and does it without a reload of its own")
        }

        function test_manualReloadClearsTheCrashedPage() {
            const { view, fake } = makeView()

            fake.simulateCrash()
            verify(view.crashed)

            view.reload()

            verify(!view.crashed)
            compare(fake.reloadCalls, 1, "the user's reload is the only one that reaches the adapter")
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
