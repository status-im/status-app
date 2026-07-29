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

            function addDownload(download) {
                const record = {
                    url: download ? download.url : "",
                    fileName: download ? (download.downloadFileName || download.suggestedFileName || "") : "",
                    state: download ? download.state : 0
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

    TestCase {
        name: "BrowserDownloadsContext"
        when: windowShown

        property bool footerVisible: false
        property int findHiddenCount: 0

        function createStore() {
            return createTemporaryObject(mockStoreComponent, root)
        }

        function createContext(store) {
            footerVisible = false
            findHiddenCount = 0
            const component = Qt.createComponent(root.downloadsContextUrl)
            verify(component.status === Component.Ready, component.errorString())
            return createTemporaryObject(component, root, {
                downloadsStore: store,
                getWebViewFn: function(index) { return null },
                getTabsCountFn: function() { return 0 },
                removeViewFn: function(index) {},
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
    }
}
