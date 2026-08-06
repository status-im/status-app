import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.stores as BrowserStores
import AppLayouts.Browser.webview

/**
 * BrowserDownloadsContext orchestration:
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
            // The one platform seam facts capabilitiesFor composes.
            property var platform: ({
                preferShareSheet: true,
                showInFolderSupported: false
            })
            function canShareFile(record) {
                if (!record || record.missingFile)
                    return false
                return record.state === AbstractWebView.DownloadState.DownloadCompleted
                    && !!record.targetPath
            }
            function canShareUrl(record) {
                return !!record && sourceUrlString(record).length > 0
            }
            function canShowInFolder(record) {
                if (!platform.showInFolderSupported || !record || record.missingFile)
                    return false
                return record.state === AbstractWebView.DownloadState.DownloadCompleted
                    && !!record.targetPath
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
            // Counter lives inside a var object: in-place mutation emits no
            // change signal, so counting from inside a capabilities binding
            // cannot invalidate that same binding (no read-write loop).
            readonly property var refreshStats: ({ calls: 0 })
            function refreshMissingFiles() { refreshStats.calls += 1 }
            function openRecord(record) {
                openRecordCalls += 1
                lastOpenedRecord = record
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
            // htmlPageLoaded/title stay on the stub on purpose: the close path must
            // read pristinePopup only, so the tests can vary them freely.
            property bool htmlPageLoaded: false
            property string title: ""
            property bool pristinePopup: false
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

    Component {
        id: fakeRecordComponent

        // Notifiable Download Record stand-in — property changes must re-trigger
        // bindings that call capabilitiesFor (the no-stale-menu guarantee).
        QtObject {
            property url url: "https://example.com/photo.png"
            property string fileName: "photo.png"
            property string mimeType: "image/png"
            property string targetPath: "/tmp/downloads/photo.png"
            property int state: AbstractWebView.DownloadState.DownloadInterrupted
            property bool missingFile: false
            property bool isInline: false
        }
    }

    Component {
        id: capsHolderComponent

        QtObject {
            property var record: null
            property var caps: null
        }
    }

    TestCase {
        name: "BrowserDownloadsContext"
        when: windowShown

        property int findHiddenCount: 0
        property var tabs: []
        property var removedIndexes: []
        property var openedUrls: []
        property bool supportsPdf: false

        function createStore() {
            return createTemporaryObject(mockStoreComponent, root)
        }

        function createContext(store) {
            findHiddenCount = 0
            tabs = []
            removedIndexes = []
            openedUrls = []
            supportsPdf = false
            const component = Qt.createComponent(root.downloadsContextUrl)
            verify(component.status === Component.Ready, component.errorString())
            const ctx = createTemporaryObject(component, root, {
                downloadsStore: store,
                getWebViewFn: function(index) { return tabs[index] || null },
                getTabsCountFn: function() { return tabs.length },
                removeViewFn: function(index) { removedIndexes.push(index) },
                hideFindUiFn: function() { findHiddenCount += 1 },
                openUrlFn: function(url) { openedUrls.push(String(url)) },
                supportsPdfFn: function() { return supportsPdf }
            })
            // The internal open seam runs for real; keep its filesystem side
            // hermetic (playerPageWritable simulates a write failure).
            ctx._openContext.mediaPlayerDirectory = "/tmp/status-player"
            ctx._openContext.ensureDirectoryFn = function(path) { return true }
            ctx._openContext.writeTextFileFn = function(path, data) { return store.playerPageWritable }
            return ctx
        }

        function test_stripHidden_whileNoSessionPills() {
            const store = createStore()
            const ctx = createContext(store)
            verify(!ctx.stripVisible, "empty strip model → no strip")

            const live = createTemporaryObject(fakeDownloadComponent, root)
            ctx.handleDownloadRequest(live)
            verify(ctx.stripVisible, "first download shows the strip")

            store.clearDownloadStrip()
            verify(!ctx.stripVisible, "emptying the model hides the strip by derivation")
        }

        function test_closingFind_restoresStrip_onlyWhenPillsRemain() {
            const store = createStore()
            const ctx = createContext(store)
            const live = createTemporaryObject(fakeDownloadComponent, root)
            ctx.handleDownloadRequest(live)

            ctx.setFindOpen(true)
            verify(!ctx.stripVisible)

            ctx.setFindOpen(false)
            verify(ctx.stripVisible)

            store.clearDownloadStrip()
            ctx.setFindOpen(true)
            ctx.setFindOpen(false)
            verify(!ctx.stripVisible)
        }

        function test_newDownload_hidesFind_andShowsStrip() {
            const store = createStore()
            const ctx = createContext(store)
            ctx.setFindOpen(true)
            verify(!ctx.stripVisible)

            const live = createTemporaryObject(fakeDownloadComponent, root)
            const before = findHiddenCount
            ctx.handleDownloadRequest(live)

            verify(findHiddenCount > before,
                   "handleDownloadRequest actively closes the open Find UI")
            verify(ctx.stripVisible)
            compare(store.downloadStripModel.length, 1)

            // Find is treated as closed: closing it again is a no-op input.
            ctx.setFindOpen(false)
            verify(ctx.stripVisible)
        }

        function test_newDownload_doesNotTouchFindUi_whenFindClosed() {
            const store = createStore()
            const ctx = createContext(store)
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const before = findHiddenCount
            ctx.handleDownloadRequest(live)
            compare(findHiddenCount, before,
                    "no hideFindUiFn call when Find was not open")
        }

        function test_userDismissedStrip_staysHidden_untilNewDownload() {
            const store = createStore()
            const ctx = createContext(store)
            const live = createTemporaryObject(fakeDownloadComponent, root)
            ctx.handleDownloadRequest(live)
            verify(ctx.stripVisible)

            ctx.dismissStrip()
            verify(!ctx.stripVisible, "close button hides the strip while pills remain")

            // A Find round-trip does not resurrect a user-dismissed strip.
            ctx.setFindOpen(true)
            ctx.setFindOpen(false)
            verify(!ctx.stripVisible)

            // The next download clears the dismissal and re-shows the strip.
            const nextLive = createTemporaryObject(fakeDownloadComponent, root)
            nextLive.url = "https://example.com/other.bin"
            nextLive.downloadFileName = "other.bin"
            ctx.handleDownloadRequest(nextLive)
            verify(ctx.stripVisible)
        }

        // ADR 0006 §6 — download-only Tab auto-close uses hostView
        function test_downloadOnlyTab_autoCloses_viaHostView() {
            const store = createStore()
            const ctx = createContext(store)
            const host = createTemporaryObject(fakeTabComponent, root)
            host.pristinePopup = true
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
            host.pristinePopup = false
            host.htmlPageLoaded = true
            host.title = "Example"
            tabs = [host]

            const live = createTemporaryObject(fakeDownloadComponent, root)
            ctx.handleDownloadRequest(live, host)

            compare(removedIndexes.length, 0)
        }

        // A Tab doing a real navigation can raise a Download before its first
        // title/load update — that Tab is the user's page, never download-only.
        function test_downloadOnlyTab_doesNotAutoClose_whenNavigatingTabDownloadsBeforeTitle() {
            const store = createStore()
            const ctx = createContext(store)
            const host = createTemporaryObject(fakeTabComponent, root)
            host.pristinePopup = false
            host.htmlPageLoaded = false
            host.title = ""
            tabs = [host]

            const live = createTemporaryObject(fakeDownloadComponent, root)
            ctx.handleDownloadRequest(live, host)

            compare(removedIndexes.length, 0, "a navigating Tab must survive its own Download")
        }

        // A download-only popup whose blank document set a title is still a popup
        // that never committed a page — the title must not keep it open.
        function test_downloadOnlyTab_autoCloses_whenPopupHasStrayTitle() {
            const store = createStore()
            const ctx = createContext(store)
            const host = createTemporaryObject(fakeTabComponent, root)
            host.pristinePopup = true
            host.title = "about:blank"
            tabs = [host]

            const live = createTemporaryObject(fakeDownloadComponent, root)
            ctx.handleDownloadRequest(live, host)

            compare(removedIndexes.length, 1, "a stray title must not keep a download-only Tab open")
            compare(removedIndexes[0], 0)
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
            // Media opens through a generated player page (one per Download Target).
            verify(openedUrls[0].startsWith("file:///tmp/status-player/player-"))
            verify(openedUrls[0].endsWith(".html"))
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

        // Per-mime routing (webm player page, write-failure → false) is pinned at
        // the open seam in tst_BrowserDownloadOpenContext; openCompletedRecord is
        // mime-agnostic, so one player-page case and one OS-fallback case suffice.
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

            ctx.handlePillClicked(record)
            compare(openedUrls.length, 1)
            compare(store.dismissCalls, 1)
            compare(store.downloadStripModel.length, 0)
            verify(!ctx.stripVisible, "last pill gone → strip hides by derivation")
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
            verify(ctx.openDownloadFromList(record))
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
            verify(!ctx.openDownloadFromList(record))
        }

        // --- capabilitiesFor: the one capability vocabulary ---

        function test_capabilitiesFor_composesStoreOpenSeamAndPlatform() {
            const store = createStore()
            const ctx = createContext(store)
            const record = createTemporaryObject(fakeRecordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted
            })

            const before = store.refreshStats.calls
            const caps = ctx.capabilitiesFor(record, null)
            verify(store.refreshStats.calls > before,
                   "Missing File refresh happens inside capabilitiesFor, not at call sites")

            verify(caps.openInBrowser, "renderable Completed type composes the open seam")
            verify(caps.shareFile)
            verify(caps.shareUrl)
            verify(!caps.showInFolder, "platform.showInFolderSupported is false here")
            verify(!caps.retry)
            verify(!caps.dismiss)
            verify(!caps.downloadsEntry, "list menus never get the Downloads entry")
            verify(caps.useShareLabels, "platform.preferShareSheet flows through")

            compare(ctx.capabilitiesFor(record, { showDismiss: true }).dismiss, true)

            // Pill strip opens ask for the Downloads entry.
            const stripCaps = ctx.capabilitiesFor(record, { showDismiss: true, showDownloadsEntry: true })
            compare(stripCaps.downloadsEntry, true)
        }

        function test_capabilitiesFor_interrupted_onlyRetryAndUrl() {
            const store = createStore()
            const ctx = createContext(store)
            const record = createTemporaryObject(fakeRecordComponent, root)

            const caps = ctx.capabilitiesFor(record, null)
            verify(caps.retry)
            verify(caps.shareUrl)
            verify(!caps.openInBrowser)
            verify(!caps.shareFile)
        }

        /// A binding on capabilitiesFor re-derives when the Record changes —
        /// the structural replacement for populateRecordMenu ordering.
        function test_capabilitiesFor_bindingUpdates_whenRecordChanges() {
            const store = createStore()
            const ctx = createContext(store)
            const interrupted = createTemporaryObject(fakeRecordComponent, root)
            const holder = createTemporaryObject(capsHolderComponent, root, {
                record: interrupted
            })
            holder.caps = Qt.binding(function() {
                return ctx.capabilitiesFor(holder.record, { showDismiss: true })
            })

            verify(holder.caps.retry)
            verify(!holder.caps.shareFile)

            // The same Record completes (e.g. after Retry) — no repopulate call.
            interrupted.state = AbstractWebView.DownloadState.DownloadCompleted
            verify(!holder.caps.retry, "capabilities follow the record's state")
            verify(holder.caps.shareFile)
            verify(holder.caps.openInBrowser)

            // Swapping the record identity re-derives too.
            const other = createTemporaryObject(fakeRecordComponent, root, {
                fileName: "other.bin",
                mimeType: "application/octet-stream",
                targetPath: ""
            })
            holder.record = other
            verify(holder.caps.retry)
            verify(!holder.caps.shareFile, "no target path → no share")

            // Break the binding before teardown destroys ctx/store under it.
            holder.caps = null
        }
    }
}
