import QtQuick
import QtTest

import AppLayouts.Browser.webview

/// The in-memory Tab set that outlives the Browser layout (CONTEXT: Drop):
/// captured on the way out, restored on the way back, whatever the Session
/// setting, with each Tab's back/forward history.
Item {
    id: root

    Component {
        id: fakeViewComponent

        QtObject {
            property string uid: ""
            property url url: ""
            property url sessionUrl: url
            property string title: ""
            property url icon: ""
            property bool offTheRecord: false
            property var profileParams: ({ localPreview: false })
            property var state: null
            property var pendingState: null

            function saveState() { return state }
            function setPendingState(s) { pendingState = s }
        }
    }

    Component {
        id: fakeTabsComponent

        QtObject {
            property int count: 0
            property int currentIndex: 0
            function activateTab(i) { currentIndex = i }
        }
    }

    Component {
        id: fakeWebViewContextComponent

        QtObject {
            id: ctx

            required property var tabsRef
            property var views: []
            property var created: []
            property int ensureLoadedCalls: 0

            function getWebView(i) { return views[i] }
            function createEmptyTab(profileParams, asStartPage, focus, url, title, icon, uid) {
                const view = fakeViewComponent.createObject(ctx, { uid: uid || "new", url: url || "" })
                created = created.concat([{ profileParams, asStartPage, url: String(url ?? ""), title, icon, uid }])
                views = views.concat([view])
                tabsRef.count = views.length
                return view
            }
            function ensureCurrentWebViewLoaded() { ensureLoadedCalls++ }
        }
    }

    Component {
        id: contextComponent

        BrowserSavedSessionContext {
            required property var webViewContextRef
            required property var tabsRef
            required property var cacheRef

            webViewContext: webViewContextRef
            tabs: tabsRef
            defaultProfileParams: "default"
            otrProfileParams: "otr"
            determineRealURL: (u) => u
            preferencesStore: QtObject {
                property var purged: null
                function getRestoreOpenTabs() { return false }
                function getOpenTabs() { return [] }
                function getCurrentTabIndex() { return 0 }
                function purgeSnapshots(uids) { purged = uids }
            }
            currentWebView: null
            sessionCache: cacheRef
        }
    }

    Component {
        id: cacheComponent

        QtObject {
            property var tabs: []
            property int currentIndex: 0
        }
    }

    TestCase {
        name: "BrowserSessionCache"

        function makeAll() {
            const tabs = createTemporaryObject(fakeTabsComponent, root)
            const webViewContext = createTemporaryObject(fakeWebViewContextComponent, root,
                                                         { tabsRef: tabs })
            const cache = createTemporaryObject(cacheComponent, root)
            const context = createTemporaryObject(contextComponent, root, {
                webViewContextRef: webViewContext, tabsRef: tabs, cacheRef: cache
            })
            verify(!!context)
            return { tabs, webViewContext, cache, context }
        }

        function test_captureKeepsBrowsingTabsWithTheirHistory() {
            const { tabs, webViewContext, cache, context } = makeAll()
            webViewContext.views = [
                fakeViewComponent.createObject(root, { uid: "a", url: "https://a.example/",
                                                       title: "A", state: "history-a" }),
                fakeViewComponent.createObject(root, { uid: "p", url: "file:///tmp/x.pdf",
                                                       profileParams: { localPreview: true } }),
                fakeViewComponent.createObject(root, { uid: "b", url: "https://b.example/",
                                                       offTheRecord: true })
            ]
            tabs.count = 3
            tabs.currentIndex = 2

            context.captureToCache()

            compare(cache.tabs.length, 2, "a local preview is no browsing Tab")
            compare(cache.tabs[0].uuid, "a")
            compare(cache.tabs[0].title, "A")
            compare(cache.tabs[0].state, "history-a")
            compare(cache.tabs[1].uuid, "b")
            verify(cache.tabs[1].offTheRecord)
            compare(cache.currentIndex, 1)
        }

        // A Tab whose url turned into a Download keeps its page, or nothing.
        function test_captureTakesTheSessionUrl() {
            const { tabs, webViewContext, cache, context } = makeAll()
            webViewContext.views = [
                fakeViewComponent.createObject(root, { uid: "d", url: "https://a.example/file.bin",
                                                       sessionUrl: "" })
            ]
            tabs.count = 1

            context.captureToCache()

            compare(cache.tabs[0].url, "")
        }

        function test_restoreRebuildsTheTabsAndLoadsOnlyTheActiveOne() {
            const { tabs, webViewContext, cache, context } = makeAll()
            cache.tabs = [
                { uuid: "a", url: "https://a.example/", title: "A", icon: "", offTheRecord: false,
                  state: "history-a" },
                { uuid: "b", url: "https://b.example/", title: "B", icon: "", offTheRecord: true,
                  state: null }
            ]
            cache.currentIndex = 1

            context.restoreSession()

            compare(webViewContext.created.length, 2)
            compare(webViewContext.created[0].uid, "a")
            compare(webViewContext.created[0].url, "https://a.example/")
            compare(webViewContext.created[0].profileParams, "default")
            verify(!webViewContext.created[0].asStartPage)
            compare(webViewContext.created[1].profileParams, "otr")
            compare(webViewContext.views[0].pendingState, "history-a")
            compare(cache.tabs.length, 0, "used once")

            tryCompare(webViewContext, "ensureLoadedCalls", 1)
            compare(tabs.currentIndex, 1)
        }

        function test_anEmptyCacheFallsBackToTheSavedSession() {
            const { webViewContext, context } = makeAll()

            context.restoreSession()

            compare(webViewContext.created.length, 1)
            verify(webViewContext.created[0].asStartPage, "the default Tab")
        }
    }
}
