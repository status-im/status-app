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
            property int openRecordCalls: 0
            // false → mediaPlayerPageUrl fails, as when the temp page cannot be written.
            property bool playerPageWritable: true
            property var lastOpenedRecord: null
            property int dismissCalls: 0

            function addDownload(download, hostView) {
                const record = {
                    url: download ? download.url : "",
                    fileName: download ? (download.downloadFileName || download.suggestedFileName || "") : "",
                    mimeType: download ? (download.mimeType || "") : "",
                    state: download ? download.state : 0,
                    originatingView: hostView || (download ? download.view : null),
                    offTheRecord: !!(hostView && hostView.offTheRecord),
                    isInline: false,
                    missingFile: false,
                    targetPath: download && download.targetPath
                                ? download.targetPath
                                : "/tmp/downloads/" + (download ? (download.downloadFileName || "file.bin") : "file.bin"),
                    isTerminal: false,
                    liveDownload: download || null
                }
                downloadModel = downloadModel.concat([record])
                downloadStripModel = [record].concat(downloadStripModel)
                return record
            }
            function reattachForRetry(record, download, hostView) {
                if (!record || !download)
                    return null
                record.url = download.url
                record.fileName = download.downloadFileName || download.suggestedFileName || record.fileName
                record.mimeType = download.mimeType || record.mimeType
                record.state = download.state
                record.missingFile = false
                record.errorString = ""
                record.liveDownload = download
                record.originatingView = hostView || download.view || record.originatingView
                const rest = []
                for (let i = 0; i < downloadModel.length; ++i) {
                    if (downloadModel[i] !== record)
                        rest.push(downloadModel[i])
                }
                downloadModel = rest.concat([record])
                dismissRecordFromStrip(record)
                downloadStripModel = [record].concat(downloadStripModel)
                return record
            }
            function acceptLiveDownload(download, record) {}
            function clearDownloadStrip() { downloadStripModel = [] }
            function getDownload(index) {
                if (index < 0 || index >= downloadModel.length)
                    return null
                return downloadModel[index]
            }
            function getStripDownload(index) {
                if (index < 0 || index >= downloadStripModel.length)
                    return null
                return downloadStripModel[index]
            }
            function canRetryFromMenu(record) {
                if (!record || record.isInline)
                    return false
                return record.state === AbstractWebView.DownloadState.DownloadInterrupted
                    || record.state === AbstractWebView.DownloadState.DownloadCancelled
            }
            function canRetryFromTap(record) {
                if (!record || record.isInline)
                    return false
                return record.state === AbstractWebView.DownloadState.DownloadInterrupted
            }
            function sourceUrlString(record) {
                return record && record.url ? String(record.url) : ""
            }
            function refreshMissingFiles() {}
            function canOpenInBrowser(record, supportsPdf) {
                if (!record || record.missingFile)
                    return false
                if (record.state !== AbstractWebView.DownloadState.DownloadCompleted)
                    return false
                const name = String(record.fileName || "").toLowerCase()
                const mime = String(record.mimeType || "").toLowerCase()
                if (mime.startsWith("image/") || name.endsWith(".png") || name.endsWith(".mp3")
                        || name.endsWith(".mp4") || name.endsWith(".webm") || name.endsWith(".html")
                        || mime === "video/webm")
                    return true
                if ((mime === "application/pdf" || name.endsWith(".pdf")) && supportsPdf)
                    return true
                return false
            }
            function isPlayableMedia(record) {
                const name = String(record?.fileName ?? "").toLowerCase()
                const mime = String(record?.mimeType ?? "").toLowerCase()
                return mime.startsWith("audio/") || mime.startsWith("video/")
                    || name.endsWith(".mp3") || name.endsWith(".mp4") || name.endsWith(".webm")
            }
            function mediaPlayerPageUrl(record) {
                if (!isPlayableMedia(record) || record.missingFile || !playerPageWritable)
                    return ""
                return "file:///tmp/player/" + String(record.fileName || "") + ".html"
            }
            function openRecord(record) {
                openRecordCalls += 1
                lastOpenedRecord = record
            }
            function openFile(index) {
                openRecord(getDownload(index))
            }
            function dismissRecordFromStrip(record) {
                dismissCalls += 1
                const next = []
                for (let i = 0; i < downloadStripModel.length; ++i) {
                    if (downloadStripModel[i] !== record)
                        next.push(downloadStripModel[i])
                }
                downloadStripModel = next
            }
        }
    }

    Component {
        id: fakeDownloadComponent

        QtObject {
            property url url: "https://example.com/report.pdf"
            property string downloadFileName: "report.pdf"
            property string suggestedFileName: downloadFileName
            property string mimeType: "application/pdf"
            property string targetPath: ""
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
        property var openedUrls: []
        property bool supportsPdf: false

        function createStore() {
            return createTemporaryObject(mockStoreComponent, root)
        }

        function createContext(store) {
            footerVisible = false
            findHiddenCount = 0
            tabs = []
            removedIndexes = []
            openedUrls = []
            supportsPdf = false
            const component = Qt.createComponent(root.downloadsContextUrl)
            verify(component.status === Component.Ready, component.errorString())
            return createTemporaryObject(component, root, {
                downloadsStore: store,
                getWebViewFn: function(index) { return tabs[index] || null },
                getTabsCountFn: function() { return tabs.length },
                removeViewFn: function(index) { removedIndexes.push(index) },
                setFooterVisibleFn: function(visible) { footerVisible = visible },
                hideFindUiFn: function() { findHiddenCount += 1 },
                openUrlFn: function(url) { openedUrls.push(String(url)) },
                supportsPdfFn: function() { return supportsPdf }
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

        function test_retry_reattachesSameRecord_noDuplicate() {
            const store = createStore()
            const ctx = createContext(store)
            const tab = createTemporaryObject(fakeTabComponent, root)
            tabs = [tab]

            const cancelledLive = createTemporaryObject(fakeDownloadComponent, root)
            cancelledLive.url = "https://example.com/clip.webm"
            cancelledLive.downloadFileName = "clip.webm"
            cancelledLive.state = AbstractWebView.DownloadState.DownloadCancelled
            const record = store.addDownload(cancelledLive, tab)
            record.state = AbstractWebView.DownloadState.DownloadCancelled
            compare(store.downloadModel.length, 1)

            verify(ctx.retryRecord(record))
            compare(tab.downloadUrlCalls, 1)
            compare(ctx._pendingRetry, record)

            const retryLive = createTemporaryObject(fakeDownloadComponent, root)
            retryLive.url = "https://example.com/clip.webm"
            retryLive.downloadFileName = "clip.webm"
            retryLive.state = AbstractWebView.DownloadState.DownloadInProgress
            ctx.handleDownloadRequest(retryLive, tab)

            compare(store.downloadModel.length, 1)
            compare(store.downloadModel[0], record)
            compare(record.liveDownload, retryLive)
            compare(record.state, AbstractWebView.DownloadState.DownloadInProgress)
            verify(!ctx._pendingRetry)
            compare(store.downloadStripModel.length, 1)
            compare(store.downloadStripModel[0], record)
        }

        function test_retry_armIsOneShot_droppedByUnrelatedRequest() {
            const store = createStore()
            const ctx = createContext(store)
            const tab = createTemporaryObject(fakeTabComponent, root)
            tabs = [tab]

            const cancelledLive = createTemporaryObject(fakeDownloadComponent, root)
            cancelledLive.url = "https://example.com/clip.webm"
            cancelledLive.downloadFileName = "clip.webm"
            cancelledLive.state = AbstractWebView.DownloadState.DownloadCancelled
            const record = store.addDownload(cancelledLive, tab)
            record.state = AbstractWebView.DownloadState.DownloadCancelled

            verify(ctx.retryRecord(record))
            compare(ctx._pendingRetry, record)

            // An unrelated download consumes the arm without matching…
            const otherLive = createTemporaryObject(fakeDownloadComponent, root)
            otherLive.url = "https://example.com/other.bin"
            otherLive.downloadFileName = "other.bin"
            ctx.handleDownloadRequest(otherLive, tab)
            verify(!ctx._pendingRetry)
            compare(store.downloadModel.length, 2)

            // …so a later same-URL download is a fresh Record, not a reattach.
            const laterLive = createTemporaryObject(fakeDownloadComponent, root)
            laterLive.url = "https://example.com/clip.webm"
            laterLive.downloadFileName = "clip.webm"
            ctx.handleDownloadRequest(laterLive, tab)
            compare(store.downloadModel.length, 3)
            compare(record.state, AbstractWebView.DownloadState.DownloadCancelled)
            verify(record.liveDownload !== laterLive)
        }

        function test_retry_armExpires_whenNoRequestArrives() {
            const store = createStore()
            const ctx = createContext(store)
            const tab = createTemporaryObject(fakeTabComponent, root)
            tabs = [tab]

            const cancelledLive = createTemporaryObject(fakeDownloadComponent, root)
            cancelledLive.url = "https://example.com/clip.webm"
            cancelledLive.downloadFileName = "clip.webm"
            cancelledLive.state = AbstractWebView.DownloadState.DownloadCancelled
            const record = store.addDownload(cancelledLive, tab)
            record.state = AbstractWebView.DownloadState.DownloadCancelled

            verify(ctx.retryRecord(record))
            compare(ctx._pendingRetry, record)

            ctx._pendingRetryExpiry.stop()
            ctx._pendingRetryExpiry.interval = 20
            ctx._pendingRetryExpiry.start()
            tryVerify(() => !ctx._pendingRetry, 1000,
                      "retry arm should expire without a matching request")

            // The download that finally arrives with the same URL is new.
            const laterLive = createTemporaryObject(fakeDownloadComponent, root)
            laterLive.url = "https://example.com/clip.webm"
            laterLive.downloadFileName = "clip.webm"
            ctx.handleDownloadRequest(laterLive, tab)
            compare(store.downloadModel.length, 2)
            verify(record.liveDownload !== laterLive)
        }

        function test_openCompleted_prefersBrowser_forRenderableType() {
            const store = createStore()
            const ctx = createContext(store)
            const record = {
                fileName: "track.mp3",
                mimeType: "audio/mpeg",
                state: AbstractWebView.DownloadState.DownloadCompleted,
                missingFile: false,
                targetPath: "/tmp/downloads/track.mp3"
            }

            verify(ctx.openCompletedRecord(record))
            compare(openedUrls.length, 1)
            verify(openedUrls[0].indexOf("track.mp3") >= 0)
            compare(store.openRecordCalls, 0)
        }

        function test_openCompleted_fallsBackToOs_forNonRenderableType() {
            const store = createStore()
            const ctx = createContext(store)
            const record = {
                fileName: "clip.mkv",
                mimeType: "video/x-matroska",
                state: AbstractWebView.DownloadState.DownloadCompleted,
                missingFile: false,
                targetPath: "/tmp/downloads/clip.mkv"
            }

            verify(ctx.openCompletedRecord(record))
            compare(openedUrls.length, 0)
            compare(store.openRecordCalls, 1)
            compare(store.lastOpenedRecord, record)
        }

        function test_openCompleted_prefersBrowser_forWebm() {
            const store = createStore()
            const ctx = createContext(store)
            const record = {
                fileName: "clip.webm",
                mimeType: "video/webm",
                state: AbstractWebView.DownloadState.DownloadCompleted,
                missingFile: false,
                targetPath: "/tmp/downloads/clip.webm"
            }

            verify(ctx.openCompletedRecord(record))
            compare(openedUrls.length, 1)
            // Media opens through a player page — navigating to the file itself makes
            // WebEngine download it again instead of playing it.
            verify(openedUrls[0].endsWith(".html"))
            verify(openedUrls[0].indexOf("clip.webm") >= 0)
            compare(store.openRecordCalls, 0)
        }

        function test_openCompleted_media_fallsBackToOs_whenPlayerPageUnavailable() {
            const store = createStore()
            store.playerPageWritable = false
            const ctx = createContext(store)
            const record = {
                fileName: "clip.webm",
                mimeType: "video/webm",
                state: AbstractWebView.DownloadState.DownloadCompleted,
                missingFile: false,
                targetPath: "/tmp/downloads/clip.webm"
            }

            verify(ctx.openCompletedRecord(record))
            compare(openedUrls.length, 0)
            compare(store.openRecordCalls, 1)
        }

        function test_openCompleted_missingFile_blocksBothRoutes() {
            const store = createStore()
            const ctx = createContext(store)
            const record = {
                fileName: "gone.mp3",
                mimeType: "audio/mpeg",
                state: AbstractWebView.DownloadState.DownloadCompleted,
                missingFile: true,
                targetPath: "/tmp/downloads/gone.mp3"
            }

            verify(!ctx.openCompletedRecord(record))
            compare(openedUrls.length, 0)
            compare(store.openRecordCalls, 0)
        }

        function test_pillClick_completed_opensThenDismisses() {
            const store = createStore()
            const ctx = createContext(store)
            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.downloadFileName = "photo.png"
            live.mimeType = "image/png"
            live.state = AbstractWebView.DownloadState.DownloadCompleted
            const record = store.addDownload(live)
            record.state = AbstractWebView.DownloadState.DownloadCompleted
            record.fileName = "photo.png"
            record.mimeType = "image/png"

            ctx.handlePillClicked(0)
            compare(openedUrls.length, 1)
            compare(store.dismissCalls, 1)
            compare(store.downloadStripModel.length, 0)
        }

        function test_listClick_completed_opensSameAsPill() {
            const store = createStore()
            const ctx = createContext(store)
            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.downloadFileName = "archive.bin"
            live.mimeType = "application/octet-stream"
            const record = store.addDownload(live)
            record.state = AbstractWebView.DownloadState.DownloadCompleted
            record.fileName = "archive.bin"
            record.mimeType = "application/octet-stream"

            // OS open still counts as opened → overview closes on true.
            verify(ctx.openDownloadFromList(true, 0))
            compare(openedUrls.length, 0)
            compare(store.openRecordCalls, 1)
            compare(store.lastOpenedRecord, record)
        }

        function test_listClick_interrupted_retries_reportsNothingOpened() {
            const store = createStore()
            const ctx = createContext(store)
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)
            record.state = AbstractWebView.DownloadState.DownloadInterrupted
            record.fileName = "a.bin"

            // Retry restarts in place — overview stays open.
            verify(!ctx.openDownloadFromList(false, 0))
        }
    }
}
