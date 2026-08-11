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
            // Retry correlation lives in the store: armRetry mints the token the
            // Backend echoes, attachDownload reattaches the Record it belongs to.
            property var pendingByToken: ({})
            property int lastToken: 0

            function armRetry(record) {
                const token = "retry-" + (++lastToken)
                pendingByToken[token] = record
                return token
            }
            function attachDownload(download, hostView, token) {
                if (!download)
                    return null
                let record = null
                const pending = token ? pendingByToken[token] : null
                if (pending) {
                    delete pendingByToken[token]
                    record = reattachForRetry(pending, download, hostView)
                }
                if (!record)
                    record = addDownload(download, hostView)
                acceptLiveDownload(download, record)
                return record
            }
            function pendingTokenCount() {
                let n = 0
                for (const token in pendingByToken)
                    n += 1
                return n
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
            property bool pristinePopup: false
            property bool offTheRecord: false
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
        property var reissues: []
        property bool hostTakesReissue: true
        property var attributions: []
        property var openedUrls: []
        property var openedFileUrls: []
        property bool supportsPdf: false

        function createStore() {
            return createTemporaryObject(mockStoreComponent, root)
        }

        function createContext(store) {
            findHiddenCount = 0
            reissues = []
            hostTakesReissue = true
            attributions = []
            openedUrls = []
            openedFileUrls = []
            supportsPdf = false
            const component = Qt.createComponent(root.downloadsContextUrl)
            verify(component.status === Component.Ready, component.errorString())
            const ctx = createTemporaryObject(component, root, {
                downloadsStore: store,
                downloadUrlFn: function(wantOtr, url, fileName, token) {
                    reissues.push({ wantOtr: !!wantOtr, url: String(url),
                                    fileName: fileName || "", token: token || "" })
                    return hostTakesReissue
                },
                hideFindUiFn: function() { findHiddenCount += 1 },
                openUrlFn: function(url) { openedUrls.push(String(url)) },
                openFileUrlFn: function(fileUrl, readAccessUrl) {
                    openedFileUrls.push({ url: String(fileUrl),
                                          readAccess: String(readAccessUrl || "") })
                },
                supportsPdfFn: function() { return supportsPdf }
            })
            // The internal open seam runs for real; keep its filesystem side
            // hermetic (playerPageWritable simulates a write failure).
            ctx._openContext.mediaPlayerDirectory = "/tmp/status-player"
            ctx._openContext.ensureDirectoryFn = function(path) { return true }
            ctx._openContext.writeTextFileFn = function(path, data) { return store.playerPageWritable }
            ctx.downloadAttributed.connect(function(view) {
                attributions.push(view)
            })
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

        // ADR 0006 §6 — the context reports who the Download belongs to; what a
        // Tab does about it (a download-only popup closes) is the host's call.
        function test_downloadAttributed_reportsHostView() {
            const store = createStore()
            const ctx = createContext(store)
            const host = createTemporaryObject(fakeTabComponent, root)

            const live = createTemporaryObject(fakeDownloadComponent, root)
            // No Backend download.view (mobile-shaped)
            ctx.handleDownloadRequest(live, host)

            compare(attributions.length, 1)
            compare(attributions[0], host)
            compare(store.downloadModel[0].originatingView, host)
        }

        // Desktop Backend downloads name their own view; a host-side re-issue
        // names nobody, and then there is no Tab to report.
        function test_downloadAttributed_fallsBackToBackendView_andSkipsViewless() {
            const store = createStore()
            const ctx = createContext(store)
            const backendView = createTemporaryObject(fakeTabComponent, root)

            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.view = backendView
            ctx.handleDownloadRequest(live, null)
            compare(attributions.length, 1)
            compare(attributions[0], backendView)

            const viewless = createTemporaryObject(fakeDownloadComponent, root)
            viewless.url = "https://example.com/other.bin"
            ctx.handleDownloadRequest(viewless, null)
            compare(attributions.length, 1, "nothing to attribute a viewless Download to")
            compare(store.downloadModel.length, 2, "…but it is still tracked")
        }

        // Which Backend runs the re-issue is the host's business; the context
        // only says which profile it must match and hands over the arm token.
        function test_retry_delegatesToHost_withProfileAndToken() {
            const store = createStore()
            const ctx = createContext(store)
            const record = {
                url: "https://example.com/a.bin",
                fileName: "a.bin",
                state: AbstractWebView.DownloadState.DownloadInterrupted,
                offTheRecord: true,
                isInline: false
            }

            verify(ctx.retryRecord(record))
            compare(reissues.length, 1)
            compare(reissues[0].wantOtr, true)
            compare(reissues[0].url, "https://example.com/a.bin")
            compare(reissues[0].fileName, "a.bin")
            verify(reissues[0].token.length > 0, "the store's arm token reaches the Backend")
            compare(store.pendingByToken[reissues[0].token], record)
        }

        function test_retry_reportsFailure_whenHostHasNoBackend() {
            const store = createStore()
            const ctx = createContext(store)
            hostTakesReissue = false

            const record = {
                url: "https://example.com/a.bin",
                fileName: "a.bin",
                state: AbstractWebView.DownloadState.DownloadInterrupted,
                offTheRecord: false,
                isInline: false
            }

            verify(!ctx.retryRecord(record))
            compare(reissues.length, 1)
        }

        // Only a plain true is a Backend taking the re-issue: a host that
        // answers nothing has not retried anything.
        function test_retry_treatsAnUndefinedHostAnswerAsFailure() {
            const store = createStore()
            const ctx = createContext(store)
            ctx.downloadUrlFn = function(wantOtr, url, fileName, token) {
                reissues.push({ wantOtr: !!wantOtr, url: String(url),
                                fileName: fileName || "", token: token || "" })
            }

            const record = {
                url: "https://example.com/a.bin",
                fileName: "a.bin",
                state: AbstractWebView.DownloadState.DownloadInterrupted,
                offTheRecord: false,
                isInline: false
            }

            verify(!ctx.retryRecord(record), "an undefined answer is not success")
            compare(reissues.length, 1, "…and the host was still asked")
        }

        function test_retry_reattachesSameRecord_noDuplicate() {
            const store = createStore()
            const ctx = createContext(store)
            const tab = createTemporaryObject(fakeTabComponent, root)

            const cancelledLive = createTemporaryObject(fakeDownloadComponent, root)
            cancelledLive.url = "https://example.com/clip.webm"
            cancelledLive.downloadFileName = "clip.webm"
            cancelledLive.state = AbstractWebView.DownloadState.DownloadCancelled
            const record = store.addDownload(cancelledLive, tab)
            record.state = AbstractWebView.DownloadState.DownloadCancelled
            compare(store.downloadModel.length, 1)

            verify(ctx.retryRecord(record))
            const token = reissues[0].token

            const retryLive = createTemporaryObject(fakeDownloadComponent, root)
            retryLive.url = "https://example.com/clip.webm"
            retryLive.downloadFileName = "clip.webm"
            retryLive.state = AbstractWebView.DownloadState.DownloadInProgress
            ctx.handleDownloadRequest(retryLive, tab, token)

            compare(store.downloadModel.length, 1)
            compare(store.downloadModel[0], record)
            compare(record.liveDownload, retryLive)
            compare(record.state, AbstractWebView.DownloadState.DownloadInProgress)
            compare(store.pendingTokenCount(), 0, "the arm is consumed by its own re-issue")
            compare(store.downloadStripModel.length, 1)
            compare(store.downloadStripModel[0], record)
        }

        // The token is why the arm survives traffic it does not belong to: an
        // unrelated Download of the very same URL cannot capture it.
        function test_retry_armIsNotCapturedByUnrelatedSameUrlDownload() {
            const store = createStore()
            const ctx = createContext(store)
            const tab = createTemporaryObject(fakeTabComponent, root)

            const cancelledLive = createTemporaryObject(fakeDownloadComponent, root)
            cancelledLive.url = "https://example.com/clip.webm"
            cancelledLive.downloadFileName = "clip.webm"
            cancelledLive.state = AbstractWebView.DownloadState.DownloadCancelled
            const record = store.addDownload(cancelledLive, tab)
            record.state = AbstractWebView.DownloadState.DownloadCancelled

            verify(ctx.retryRecord(record))
            const token = reissues[0].token

            // Same URL, no token: the page started this one, so it is a new Record.
            const otherLive = createTemporaryObject(fakeDownloadComponent, root)
            otherLive.url = "https://example.com/clip.webm"
            otherLive.downloadFileName = "clip.webm"
            ctx.handleDownloadRequest(otherLive, tab, "")
            compare(store.downloadModel.length, 2)
            compare(record.state, AbstractWebView.DownloadState.DownloadCancelled)
            verify(record.liveDownload !== otherLive)

            // The re-issue still lands on the original Record whenever it arrives.
            const retryLive = createTemporaryObject(fakeDownloadComponent, root)
            retryLive.url = "https://example.com/clip.webm"
            retryLive.downloadFileName = "clip.webm"
            retryLive.state = AbstractWebView.DownloadState.DownloadInProgress
            ctx.handleDownloadRequest(retryLive, tab, token)
            compare(store.downloadModel.length, 2)
            compare(record.liveDownload, retryLive)
        }

        // A stale token names a Record that is no longer armed: track the
        // Download rather than lose it.
        function test_unknownToken_startsANewRecord() {
            const store = createStore()
            const ctx = createContext(store)
            const live = createTemporaryObject(fakeDownloadComponent, root)

            ctx.handleDownloadRequest(live, null, "retry-does-not-exist")
            compare(store.downloadModel.length, 1)
            compare(store.downloadModel[0].liveDownload, live)
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

        /// A Backend that needs no player page opens the media file itself, and
        /// the direct-load route must reach the host's loadFileUrl plumbing.
        function test_openInBrowser_directMediaLoad_reachesFileUrlPlumbing() {
            const store = createStore()
            const ctx = createContext(store)
            const record = createTemporaryObject(fakeRecordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted,
                fileName: "tune.mp3",
                mimeType: "audio/mpeg",
                targetPath: "/tmp/downloads/tune.mp3"
            })

            ctx._openContext.mediaPlayerPageRequired = false
            verify(ctx.openInBrowserRecord(record))
            compare(openedUrls.length, 0, "no player page navigation on this Backend")
            compare(openedFileUrls.length, 1)
            verify(openedFileUrls[0].url.indexOf("tune.mp3") >= 0)
            compare(openedFileUrls[0].readAccess, "", "empty grant = the file's own directory")

            // Flipping the Capability back restores the player-page route.
            ctx._openContext.mediaPlayerPageRequired = true
            verify(ctx.openInBrowserRecord(record))
            compare(openedFileUrls.length, 1)
            compare(openedUrls.length, 1)
            verify(openedUrls[0].indexOf("/status-player/player-") > 0)
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
