import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.webview

/**
 * Retained Views (ADR 0006 §6): closing a Tab that still owns non-terminal
 * Downloads keeps its Web View alive; only viewDownloadsCleared ends that.
 * Fake views suffice — the context touches just retained/focus/parent/detachView.
 *
 * Plus the two Tab-set lookups the same object owns, because Retention is what
 * makes them subtle: removeViewFor (close the Tab backing a named Web View) and
 * firstLiveDownloadBackend (the Tab a host-side re-issue may run on, §7).
 */
Item {
    id: root

    width: 400
    height: 400

    // Appended on destruction, so we never probe a dangling handle.
    property var destroyedViewNames: []

    Component {
        id: hostStackComponent

        Item { width: 1; height: 1 }
    }

    Component {
        id: fakeWebViewComponent

        Item {
            id: fakeView

            property string viewName: ""
            property bool offTheRecord: false
            property bool retained: false
            property int detachCalls: 0

            function detachView() { detachCalls += 1 }

            Component.onDestruction: root.destroyedViewNames =
                root.destroyedViewNames.concat([fakeView.viewName])
        }
    }

    // A Tab whose Backend can take a Download re-issue (mobile shape).
    Component {
        id: fakeDownloadTabComponent

        Item {
            id: downloadTab

            property string viewName: ""
            property bool offTheRecord: false
            property bool retained: false
            property ProfileParams profileParams: null
            property var downloadCalls: []

            function detachView() {}
            function downloadUrl(url, fileName, token) {
                downloadTab.downloadCalls = downloadTab.downloadCalls.concat(
                    [{ url: String(url), fileName: fileName || "", token: token || "" }])
            }
        }
    }

    Component {
        id: previewParamsComponent

        ProfileParams {
            userId: "user-1"
            userAgent: ""
            scripts: []
            offTheRecord: true
            localPreview: true
        }
    }

    Component {
        id: downloadsStoreComponent

        // Minimal DownloadsStore seam BrowserWebViewContext reads for retention.
        QtObject {
            id: store

            signal viewDownloadsCleared(var view)

            property var busyViews: []

            function viewHasNonTerminalDownloads(view) {
                return !!view && store.busyViews.indexOf(view) !== -1
            }

            // The view's last Download went terminal, so the signal fires.
            function finishDownloadsFor(view) {
                const next = []
                for (let i = 0; i < store.busyViews.length; ++i) {
                    if (store.busyViews[i] !== view)
                        next.push(store.busyViews[i])
                }
                store.busyViews = next
                store.viewDownloadsCleared(view)
            }
        }
    }

    Component {
        id: tabsModelComponent

        QtObject {
            id: tabsModel

            property int currentIndex: 0
            property int count: 2
            property var removedIndexes: []

            function createEmptyTab() {}
            function removeTab(index) {
                tabsModel.removedIndexes = tabsModel.removedIndexes.concat([index])
                tabsModel.count = Math.max(0, tabsModel.count - 1)
                if (tabsModel.currentIndex >= tabsModel.count)
                    tabsModel.currentIndex = Math.max(0, tabsModel.count - 1)
            }
        }
    }

    Component {
        id: browserWebViewContextComponent

        BrowserWebViewContext {
            required property Item hostStack
            required property var tabsModelRef
            required property var downloadsStoreRef

            thirdpartyServicesEnabled: true
            isDebugEnabled: false
            isMobile: true
            hasPopups: false
            browserSettings: QtObject {}
            connectorController: null
            dappsEnabled: false
            hostStackLayout: hostStack
            tabsModel: tabsModelRef
            defaultProfileParams: ProfileParams {
                userId: ""
                userAgent: ""
                scripts: []
                offTheRecord: false
            }
            otrProfileParams: ProfileParams {
                userId: ""
                userAgent: ""
                scripts: []
                offTheRecord: true
            }
            bookmarksStore: QtObject {}
            downloadsStore: downloadsStoreRef
            determineRealURLFn: function(url) { return url }
            downloadRequestHandler: function() {}
            linkLongPressHandler: function() {}
            sslErrorHandler: function() {}
            jsDialogHandler: function() {}
            findTextFinishedHandler: function() {}
            savedSessionContext: QtObject {
                function seedWebView() {}
            }
        }
    }

    TestCase {
        name: "BrowserRetainedViews"
        when: windowShown

        property Item hostStack: null
        property var store: null
        property var tabsModel: null
        property BrowserWebViewContext webViewContext: null
        property var firstView: null
        property var secondView: null

        function init() {
            root.destroyedViewNames = []

            hostStack = createTemporaryObject(hostStackComponent, root)
            store = createTemporaryObject(downloadsStoreComponent, root)
            tabsModel = createTemporaryObject(tabsModelComponent, root)

            // Two tabs: the "last tab" branch would build a real Web View.
            firstView = createTemporaryObject(fakeWebViewComponent, hostStack,
                                              { viewName: "first" })
            secondView = createTemporaryObject(fakeWebViewComponent, hostStack,
                                               { viewName: "second" })

            webViewContext = createTemporaryObject(browserWebViewContextComponent, root, {
                hostStack: hostStack,
                tabsModelRef: tabsModel,
                downloadsStoreRef: store
            })
        }

        // Closing never cancels: the view stays alive, out of the Tab set (§6).
        function test_closingTab_retainsViewWithNonTerminalDownloads() {
            store.busyViews = [firstView]

            webViewContext.removeView(0)

            compare(tabsModel.removedIndexes.length, 1, "the tab is still closed")
            compare(tabsModel.removedIndexes[0], 0)

            verify(firstView.retained, "the view is marked Retained")
            compare(firstView.parent, null,
                    "a Retained View leaves the host stack so children stay 1:1 with tabs")
            compare(firstView.detachCalls, 0,
                    "detachView() would abort the transfer — never on the retain path")
            compare(root.destroyedViewNames.length, 0, "the view is not destroyed")

            compare(webViewContext._retainedViews.length, 1)
            compare(webViewContext._retainedViews[0], firstView)
        }

        // Clearing ends the retention: it leaves _retainedViews and dies.
        function test_viewDownloadsCleared_dropsAndDestroysRetainedView() {
            store.busyViews = [firstView]
            webViewContext.removeView(0)
            compare(webViewContext._retainedViews.length, 1)

            store.finishDownloadsFor(firstView)

            compare(webViewContext._retainedViews.length, 0,
                    "the cleared view leaves _retainedViews")
            tryVerify(() => root.destroyedViewNames.indexOf("first") !== -1, 1000,
                      "the cleared Retained View is destroyed")
            compare(root.destroyedViewNames.indexOf("second"), -1,
                    "the still-open tab's view is untouched")
        }

        // Nothing to finish → the ordinary close path, destroyed right away.
        function test_closingTab_destroysViewWithoutNonTerminalDownloads() {
            store.busyViews = []

            webViewContext.removeView(0)

            verify(!firstView.retained)
            compare(webViewContext._retainedViews.length, 0)
            compare(firstView.detachCalls, 1, "the ordinary close path detaches")
            tryVerify(() => root.destroyedViewNames.indexOf("first") !== -1, 1000,
                      "a view with no non-terminal Downloads is destroyed on close")
        }

        // A cleared signal for a view that was never retained must not destroy it.
        function test_viewDownloadsCleared_ignoresUnknownView() {
            store.busyViews = [firstView]
            webViewContext.removeView(0)

            store.finishDownloadsFor(secondView)

            compare(webViewContext._retainedViews.length, 1,
                    "an unrelated view does not drop the Retained View")
            compare(webViewContext._retainedViews[0], firstView)
            compare(root.destroyedViewNames.length, 0)
        }
    }

    /// The Tab set is the context's, so looking a Tab up in it is too — the host
    /// names a Web View and never an index.
    TestCase {
        name: "BrowserTabSetLookups"
        when: windowShown

        property Item hostStack: null
        property var tabsModel: null
        property BrowserWebViewContext webViewContext: null

        /// Builds one Tab per entry, in order, and a context over them.
        /// `component` is fakeWebViewComponent (no Download Backend) unless the
        /// entry names another.
        function makeTabs(entries) {
            root.destroyedViewNames = []

            hostStack = createTemporaryObject(hostStackComponent, root)
            tabsModel = createTemporaryObject(tabsModelComponent, root)

            const views = []
            for (let i = 0; i < entries.length; ++i) {
                const entry = entries[i]
                const component = entry.component || fakeDownloadTabComponent
                const props = {}
                for (const key in entry) {
                    if (key !== "component")
                        props[key] = entry[key]
                }
                views.push(createTemporaryObject(component, hostStack, props))
            }
            tabsModel.count = views.length

            webViewContext = createTemporaryObject(browserWebViewContextComponent, root, {
                hostStack: hostStack,
                tabsModelRef: tabsModel,
                downloadsStoreRef: createTemporaryObject(downloadsStoreComponent, root)
            })
            return views
        }

        function test_removeViewFor_closesTheTabBackingThatView() {
            const views = makeTabs([{ viewName: "a" }, { viewName: "b" },
                                    { viewName: "c" }])

            verify(webViewContext.removeViewFor(views[1]))

            compare(tabsModel.removedIndexes.length, 1)
            compare(tabsModel.removedIndexes[0], 1, "the middle tab, not the current one")
        }

        function test_removeViewFor_ignoresAViewThatIsNoTab() {
            const views = makeTabs([{ viewName: "a" }, { viewName: "b" }])
            // A Retained View is alive but out of the Tab set (§6).
            const stranger = createTemporaryObject(fakeDownloadTabComponent, root,
                                                   { viewName: "retained" })

            verify(!webViewContext.removeViewFor(stranger))
            verify(!webViewContext.removeViewFor(null))
            compare(tabsModel.removedIndexes.length, 0, "no tab closes on a miss")
        }

        function test_firstLiveDownloadBackend_skipsRetainedAndPreviewTabs() {
            const preview = createTemporaryObject(previewParamsComponent, root)
            // A local preview is always off the record, so it is exactly the
            // Incognito re-issue it could capture.
            const views = makeTabs([
                // Alive, but finishing only what it already owns (§6).
                { viewName: "retained", offTheRecord: true, retained: true },
                // Isolated, script-free, and no browsing profile at all (§8).
                { viewName: "preview", offTheRecord: true, profileParams: preview },
                // Not a Download Backend — a fake with no downloadUrl.
                { viewName: "plain", offTheRecord: true, component: fakeWebViewComponent },
                { viewName: "live", offTheRecord: true }
            ])

            compare(webViewContext.firstLiveDownloadBackend(true), views[3])
        }

        function test_firstLiveDownloadBackend_matchesTheRequestedProfile() {
            const views = makeTabs([{ viewName: "standard", offTheRecord: false },
                                    { viewName: "incognito", offTheRecord: true }])

            compare(webViewContext.firstLiveDownloadBackend(false), views[0])
            compare(webViewContext.firstLiveDownloadBackend(true), views[1],
                    "the profile match is mandatory, never best-effort (§7)")
        }

        // Rather than downgrade the re-issue onto the wrong profile (§7).
        function test_firstLiveDownloadBackend_returnsNullWhenNothingMatches() {
            const preview = createTemporaryObject(previewParamsComponent, root)
            makeTabs([{ viewName: "retained", offTheRecord: true, retained: true },
                      { viewName: "preview", offTheRecord: true,
                        profileParams: preview },
                      { viewName: "standard", offTheRecord: false }])

            compare(webViewContext.firstLiveDownloadBackend(true), null)
        }
    }
}
