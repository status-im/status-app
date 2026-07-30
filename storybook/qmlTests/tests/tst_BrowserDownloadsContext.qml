import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Browser.webview

/**
 * BrowserDownloadsContext orchestration (browser-downloads-ux 05):
 * Find in page XOR Download Pill strip on mobile.
 * Uses the typed DownloadsStore stub (Storybook import path) with a minimal
 * session strip API — same pattern as BrowserLayoutPage.
 */
Item {
    id: root
    width: 400
    height: 400

    readonly property url downloadsContextUrl: Qt.resolvedUrl(
        "../../../ui/app/AppLayouts/Browser/webview/BrowserDownloadsContext.qml")

    Component {
        id: mockStoreComponent

        BrowserStores.DownloadsStore {
            property var downloadModel: []
            property var downloadStripModel: []

            function addDownload(download, hostView) {
                const record = {
                    url: download ? download.url : "",
                    fileName: download ? (download.downloadFileName || download.suggestedFileName || "") : "",
                    state: download ? download.state : 0,
                    originatingView: hostView || (download ? download.view : null),
                    offTheRecord: !!(hostView && hostView.offTheRecord),
                    isInline: false,
                    missingFile: false,
                    targetPath: "",
                    isTerminal: false
                }
                downloadModel = downloadModel.concat([record])
                downloadStripModel = downloadStripModel.concat([record])
                return record
            }
            function acceptLiveDownload(download, record) {}
            function clearDownloadStrip() { downloadStripModel = [] }
            function getStripDownload(index) {
                if (index < 0 || index >= downloadStripModel.length)
                    return null
                return downloadStripModel[index]
            }
            function canRetryFromMenu(record) {
                return !!record && record.state === AbstractWebView.DownloadState.DownloadInterrupted
            }
            function canRetryFromTap(record) {
                return canRetryFromMenu(record)
            }
            function sourceUrlString(record) {
                return record && record.url ? String(record.url) : ""
            }
        }
    }

    Component {
        id: fakeDownloadComponent

        QtObject {
            property url url: "https://example.com/report.pdf"
            property string downloadFileName: "report.pdf"
            property string suggestedFileName: downloadFileName
            property int state: AbstractWebView.DownloadState.DownloadRequested
            property var view: null
        }
    }

    Component {
        id: fakeTabComponent

        QtObject {
            property bool htmlPageLoaded: false
            property string title: ""
            property bool offTheRecord: false
            property bool retained: false
            property int downloadUrlCalls: 0
            property string lastDownloadUrl: ""
            property string lastSuggestedName: ""

            function downloadUrl(url, suggestedFileName) {
                downloadUrlCalls += 1
                lastDownloadUrl = String(url)
                lastSuggestedName = suggestedFileName || ""
            }
        }
    }

    TestCase {
        name: "BrowserDownloadsContext"
        when: windowShown

        property bool footerVisible: false
        property int findHiddenCount: 0
        property var tabs: []
        property var removedIndexes: []

        function createStore() {
            return createTemporaryObject(mockStoreComponent, root)
        }

        function createContext(store) {
            footerVisible = false
            findHiddenCount = 0
            tabs = []
            removedIndexes = []
            const component = Qt.createComponent(root.downloadsContextUrl)
            verify(component.status === Component.Ready, component.errorString())
            return createTemporaryObject(component, root, {
                downloadsStore: store,
                getWebViewFn: function(index) { return tabs[index] || null },
                getTabsCountFn: function() { return tabs.length },
                removeViewFn: function(index) { removedIndexes.push(index) },
                setFooterVisibleFn: function(visible) { footerVisible = visible },
                hideFindUiFn: function() { findHiddenCount += 1 }
            })
        }

        function test_openingFind_hidesDownloadStrip() {
            const store = createStore()
            const ctx = createContext(store)
            const live = createTemporaryObject(fakeDownloadComponent, root)
            ctx.handleDownloadRequest(live)
            verify(footerVisible)

            ctx.setFindUiActive(true)
            verify(!footerVisible)
            verify(ctx.findUiActive)
        }

        function test_closingFind_restoresStrip_onlyWhenPillsRemain() {
            const store = createStore()
            const ctx = createContext(store)
            const live = createTemporaryObject(fakeDownloadComponent, root)
            ctx.handleDownloadRequest(live)

            ctx.setFindUiActive(true)
            verify(!footerVisible)

            ctx.setFindUiActive(false)
            verify(footerVisible)

            store.clearDownloadStrip()
            ctx.setFindUiActive(true)
            ctx.setFindUiActive(false)
            verify(!footerVisible)
        }

        function test_newDownload_hidesFind_andShowsStrip() {
            const store = createStore()
            const ctx = createContext(store)
            ctx.setFindUiActive(true)
            verify(ctx.findUiActive)
            verify(!footerVisible)

            const live = createTemporaryObject(fakeDownloadComponent, root)
            const before = findHiddenCount
            ctx.handleDownloadRequest(live)

            verify(!ctx.findUiActive)
            verify(findHiddenCount > before)
            verify(footerVisible)
            compare(store.downloadStripModel.length, 1)
        }

        // ADR 0006 §6 / issue 06 — download-only Tab auto-close uses hostView
        function test_downloadOnlyTab_autoCloses_viaHostView() {
            const store = createStore()
            const ctx = createContext(store)
            const host = createTemporaryObject(fakeTabComponent, root)
            host.htmlPageLoaded = false
            host.title = ""
            tabs = [host]

            const live = createTemporaryObject(fakeDownloadComponent, root)
            // No Backend download.view (mobile-shaped)
            ctx.handleDownloadRequest(live, host)

            compare(removedIndexes.length, 1)
            compare(removedIndexes[0], 0)
            compare(store.downloadModel[0].originatingView, host)
        }

        function test_downloadOnlyTab_doesNotAutoClose_whenPageLoaded() {
            const store = createStore()
            const ctx = createContext(store)
            const host = createTemporaryObject(fakeTabComponent, root)
            host.htmlPageLoaded = true
            host.title = "Example"
            tabs = [host]

            const live = createTemporaryObject(fakeDownloadComponent, root)
            ctx.handleDownloadRequest(live, host)

            compare(removedIndexes.length, 0)
        }

        function test_retry_requiresMatchingProfile_noFallback() {
            const store = createStore()
            const ctx = createContext(store)
            const standardTab = createTemporaryObject(fakeTabComponent, root)
            standardTab.offTheRecord = false
            tabs = [standardTab]

            const record = {
                url: "https://example.com/a.bin",
                fileName: "a.bin",
                state: AbstractWebView.DownloadState.DownloadInterrupted,
                offTheRecord: true,
                isInline: false
            }

            verify(!ctx.retryRecord(record))
            compare(standardTab.downloadUrlCalls, 0)

            const otrTab = createTemporaryObject(fakeTabComponent, root)
            otrTab.offTheRecord = true
            tabs = [standardTab, otrTab]
            verify(ctx.retryRecord(record))
            compare(otrTab.downloadUrlCalls, 1)
            compare(otrTab.lastDownloadUrl, "https://example.com/a.bin")
        }

        function test_retry_skipsRetainedViews() {
            const store = createStore()
            const ctx = createContext(store)
            const retainedTab = createTemporaryObject(fakeTabComponent, root)
            retainedTab.offTheRecord = false
            retainedTab.retained = true
            tabs = [retainedTab]

            const record = {
                url: "https://example.com/a.bin",
                fileName: "a.bin",
                state: AbstractWebView.DownloadState.DownloadInterrupted,
                offTheRecord: false,
                isInline: false
            }

            verify(!ctx.retryRecord(record))
            compare(retainedTab.downloadUrlCalls, 0)
        }
    }
}
