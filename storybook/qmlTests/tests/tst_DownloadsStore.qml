import QtQuick
import QtTest

import AppLayouts.Browser.adapters

import utils

/**
 * DownloadsStore seam: Download Records own list identity; a fake live Download
 * attaches for progress and can be destroyed without losing the Record.
 * Loads the real store (stubs are empty by architecture guide).
 * See ADR 0006 / .scratch/browser-downloads/issues/01-prefactor-download-records.md
 */
Item {
    id: root

    // Real store — stubs/AppLayouts/Browser/stores/DownloadsStore is an empty QtObject.
    readonly property url downloadsStoreUrl: Qt.resolvedUrl(
        "../../../ui/app/AppLayouts/Browser/stores/DownloadsStore.qml")

    Component {
        id: fakeDownloadComponent

        QtObject {
            property url url: "https://example.com/report.pdf"
            property string downloadFileName: "report.pdf"
            property string downloadDirectory: "/tmp/downloads"
            property string suggestedFileName: downloadFileName
            property string mimeType: "application/pdf"
            property int receivedBytes: 0
            property int totalBytes: 1000
            property int state: AbstractWebView.DownloadState.DownloadRequested
            property bool isPaused: false
            property bool isInline: false
            property bool offTheRecord: false
            property string errorString: ""
            property string destinationPath: downloadDirectory + "/" + downloadFileName
            property bool accepted: false
            // When true, cancel() leaves isPaused set — WebEngine can do this.
            property bool leavePausedOnCancel: false

            function accept() { accepted = true }
            function cancel() {
                if (!leavePausedOnCancel)
                    isPaused = false
                state = AbstractWebView.DownloadState.DownloadCancelled
            }
            function pause() {
                isPaused = true
                // WebEngine-shaped: stay InProgress while paused; isPaused carries the pause.
                state = AbstractWebView.DownloadState.DownloadInProgress
            }
            function resume() {
                isPaused = false
                state = AbstractWebView.DownloadState.DownloadInProgress
            }

            function advance(bytes) {
                receivedBytes = bytes
                isPaused = false
                state = AbstractWebView.DownloadState.DownloadInProgress
            }

            function complete() {
                receivedBytes = totalBytes
                isPaused = false
                state = AbstractWebView.DownloadState.DownloadCompleted
            }
        }
    }

    Component {
        id: fakeMobileDownloadComponent

        QtObject {
            property url url: "https://example.com/a.bin"
            property string suggestedFileName: "a.bin"
            property string mimeType: "application/octet-stream"
            property int receivedBytes: 0
            property int totalBytes: -1
            property int state: AbstractWebView.DownloadState.DownloadRequested
            property bool isPaused: false
            property bool isInline: false
            property string destinationPath: ""
            property string acceptedPath: ""

            // Mobile-shaped: accept requires a Download Target path.
            function accept(path) {
                acceptedPath = path
                destinationPath = path
            }
            function cancel() {}
            function pause() {}
            function resume() {}
        }
    }

    Component {
        id: fakePreferencesComponent

        QtObject {
            property var _preferences: ({})

            function put(category, key, value) {
                _preferences[category + "\0" + key] = String(value)
            }
            function get(category, key) {
                return _preferences[category + "\0" + key] || ""
            }
            function getDownloadHistoryRaw() {
                return get(BrowserPreferenceKeys.downloadsHistoryCategory,
                           BrowserPreferenceKeys.keyDownloadRecords)
            }
            function setDownloadHistoryRaw(raw) {
                put(BrowserPreferenceKeys.downloadsHistoryCategory,
                    BrowserPreferenceKeys.keyDownloadRecords, raw || "[]")
            }
            function clearDownloadHistoryRaw() {
                setDownloadHistoryRaw("[]")
            }
        }
    }

    Component {
        id: fakeViewComponent
        QtObject {
            property bool offTheRecord: false
            property bool retained: false
            property bool htmlPageLoaded: false
            property string title: ""
        }
    }

    TestCase {
        name: "DownloadsStore"
        when: windowShown

        function createStore() {
            const component = Qt.createComponent(root.downloadsStoreUrl)
            verify(component.status === Component.Ready, component.errorString())
            const store = createTemporaryObject(component, root)
            store.ensureDirectoryFn = function(path) { return true }
            return store
        }

        function test_createRecord_fromLiveDownload() {
            const store = createStore()
            const live = createTemporaryObject(fakeDownloadComponent, root)

            const record = store.addDownload(live)

            verify(!!record)
            compare(store.downloadModel.length, 1)
            compare(store.getDownload(0), record)
            compare(record.url, live.url)
            compare(record.fileName, "report.pdf")
            compare(record.downloadDirectory, "/tmp/downloads")
            compare(record.state, AbstractWebView.DownloadState.DownloadRequested)
            compare(record.receivedBytes, 0)
            compare(record.totalBytes, 1000)
            compare(record.liveDownload, live)
        }

        function test_progressBinding_fromLiveDownload() {
            const store = createStore()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)

            live.advance(400)

            compare(record.receivedBytes, 400)
            compare(record.state, AbstractWebView.DownloadState.DownloadInProgress)
            compare(record.isPaused, false)
        }

        function test_recordSurvives_afterLiveDownloadDestroyed() {
            const store = createStore()
            const live = fakeDownloadComponent.createObject(root)
            const record = store.addDownload(live)

            live.advance(700)
            live.complete()

            compare(record.state, AbstractWebView.DownloadState.DownloadCompleted)
            compare(record.receivedBytes, 1000)

            live.destroy()
            wait(0)

            compare(record.liveDownload, null)
            compare(record.state, AbstractWebView.DownloadState.DownloadCompleted)
            compare(record.receivedBytes, 1000)
            compare(record.fileName, "report.pdf")
            compare(record.downloadDirectory, "/tmp/downloads")
            compare(store.downloadModel.length, 1)
            compare(store.getDownload(0), record)
        }

        function test_pauseResumeCancel_forwardedToLive() {
            const store = createStore()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)

            live.advance(100)
            record.pause()
            compare(record.state, AbstractWebView.DownloadState.DownloadPaused)
            compare(record.isPaused, true)

            record.resume()
            compare(record.state, AbstractWebView.DownloadState.DownloadInProgress)
            compare(record.isPaused, false)

            record.cancel()
            compare(record.state, AbstractWebView.DownloadState.DownloadCancelled)
        }

        function test_cancel_whilePaused_clearsResumeUi() {
            const store = createStore()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.leavePausedOnCancel = true
            const record = store.addDownload(live)

            live.advance(100)
            record.pause()
            compare(record.state, AbstractWebView.DownloadState.DownloadPaused)
            compare(record.isPaused, true)

            record.cancel()
            compare(record.state, AbstractWebView.DownloadState.DownloadCancelled)
            compare(record.isPaused, false)
        }

        function test_cancel_afterLiveDestroyed_updatesRecord() {
            const store = createStore()
            const live = fakeDownloadComponent.createObject(root)
            const record = store.addDownload(live)

            live.advance(50)
            live.destroy()
            wait(0)

            compare(record.liveDownload, null)
            record.cancel()
            compare(record.state, AbstractWebView.DownloadState.DownloadCancelled)
            compare(record.isPaused, false)
        }

        function test_downloadModel_isArrayNotObjectModel() {
            const store = createStore()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            store.addDownload(live)

            // ObjectModel crashes ListView (QQuickItem::x on QtObject). Must be a JS array.
            verify(Array.isArray(store.downloadModel))
            compare(typeof store.downloadModel.append, "undefined")
        }

        function test_resolveDownloadTarget_usesDownloadsDirAndSuggestedName() {
            const store = createStore()
            store.downloadsDirectory = "/tmp/status-downloads"
            store.pathExistsFn = function(path) { return false }

            compare(store.resolveDownloadTarget("report.pdf"),
                    "/tmp/status-downloads/report.pdf")
        }

        function test_resolveDownloadTarget_addsCollisionSuffixes() {
            const store = createStore()
            store.downloadsDirectory = "/tmp/status-downloads"
            store.pathExistsFn = function(path) {
                return path === "/tmp/status-downloads/report.pdf"
                    || path === "/tmp/status-downloads/report (1).pdf"
            }

            compare(store.resolveDownloadTarget("report.pdf"),
                    "/tmp/status-downloads/report (2).pdf")
        }

        function test_resolveDownloadTarget_skipsTargetsClaimedByRecords() {
            const store = createStore()
            store.downloadsDirectory = "/tmp/status-downloads"
            store.pathExistsFn = function(path) { return false }

            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)
            record.downloadDirectory = "/tmp/status-downloads"
            record.fileName = "report.pdf"

            compare(store.resolveDownloadTarget("report.pdf"),
                    "/tmp/status-downloads/report (1).pdf")
        }

        function test_acceptLiveDownload_mobileShaped_passesTargetPath() {
            const store = createStore()
            store.downloadsDirectory = "/tmp/status-downloads"
            store.pathExistsFn = function(path) { return false }

            const live = createTemporaryObject(fakeMobileDownloadComponent, root)
            const record = store.addDownload(live)
            store.acceptLiveDownload(live, record)

            compare(live.acceptedPath, "/tmp/status-downloads/a.bin")
            compare(record.fileName, "a.bin")
            compare(record.downloadDirectory, "/tmp/status-downloads")
            compare(record.targetPath, "/tmp/status-downloads/a.bin")
        }

        function test_acceptLiveDownload_webEngineShaped_setsDirAndAccepts() {
            const store = createStore()
            store.downloadsDirectory = "/tmp/status-downloads"
            store.pathExistsFn = function(path) { return false }

            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)
            store.acceptLiveDownload(live, record)

            verify(live.accepted)
            compare(live.downloadDirectory, "/tmp/status-downloads")
            compare(live.downloadFileName, "report.pdf")
            compare(record.fileName, "report.pdf")
            compare(record.downloadDirectory, "/tmp/status-downloads")
        }

        function createStoreWithPrefs() {
            const prefs = createTemporaryObject(fakePreferencesComponent, root)
            const store = createStore()
            store.preferencesStore = prefs
            store.historySaveDebounceMs = 0
            store.historyCap = 200
            store.downloadsDirectory = "/tmp/status-downloads"
            store.pathExistsFn = function(path) { return false }
            return store
        }

        function flushHistory(store) {
            store.saveDownloadHistoryNow()
        }

        function test_history_persistsOnCreateAndTerminal_notProgress() {
            const store = createStoreWithPrefs()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)
            store.acceptLiveDownload(live, record)
            flushHistory(store)

            const savedAfterCreate = JSON.parse(store.preferencesStore.getDownloadHistoryRaw() || "[]")
            compare(savedAfterCreate.length, 1)
            compare(savedAfterCreate[0].fileName, "report.pdf")

            live.advance(400)
            flushHistory(store)
            const savedMid = JSON.parse(store.preferencesStore.getDownloadHistoryRaw() || "[]")
            // Progress must not be written into History.
            compare(savedMid[0].receivedBytes, undefined)

            live.complete()
            flushHistory(store)
            const savedDone = JSON.parse(store.preferencesStore.getDownloadHistoryRaw() || "[]")
            compare(savedDone[0].state, AbstractWebView.DownloadState.DownloadCompleted)
            compare(savedDone[0].fileName, "report.pdf")
            compare(savedDone[0].downloadDirectory, "/tmp/status-downloads")
        }

        function test_history_excludesIncognito() {
            const store = createStoreWithPrefs()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)
            record.offTheRecord = true
            store.acceptLiveDownload(live, record)
            live.complete()
            flushHistory(store)

            const saved = JSON.parse(store.preferencesStore.getDownloadHistoryRaw() || "[]")
            compare(saved.length, 0)
            compare(store.downloadModel.length, 1) // still session-visible
        }

        function test_history_restore_incompleteBecomesInterrupted() {
            const prefs = createTemporaryObject(fakePreferencesComponent, root)
            prefs.setDownloadHistoryRaw(JSON.stringify([{
                url: "https://example.com/x.bin",
                fileName: "x.bin",
                downloadDirectory: "/tmp/status-downloads",
                mimeType: "application/octet-stream",
                isInline: false,
                startTime: new Date().toISOString(),
                state: AbstractWebView.DownloadState.DownloadInProgress,
                totalBytes: 500,
                errorString: ""
            }]))

            const store = createStore()
            store.preferencesStore = prefs
            store.pathExistsFn = function(path) { return false }
            store.restoreDownloadHistory()

            compare(store.downloadModel.length, 1)
            compare(store.getDownload(0).fileName, "x.bin")
            compare(store.getDownload(0).state, AbstractWebView.DownloadState.DownloadInterrupted)
            compare(store.getDownload(0).liveDownload, null)
        }

        function test_history_capEvictsOldest() {
            const store = createStoreWithPrefs()
            store.historyCap = 2

            for (let i = 0; i < 3; ++i) {
                const live = createTemporaryObject(fakeDownloadComponent, root)
                live.downloadFileName = "f" + i + ".bin"
                live.suggestedFileName = live.downloadFileName
                const record = store.addDownload(live)
                store.acceptLiveDownload(live, record)
                live.complete()
            }
            flushHistory(store)

            const saved = JSON.parse(store.preferencesStore.getDownloadHistoryRaw() || "[]")
            compare(saved.length, 2)
            compare(saved[0].fileName, "f1.bin")
            compare(saved[1].fileName, "f2.bin")
        }

        function test_clearDownloadHistory_clearsRecordsKeepsSessionFilesUntouched() {
            const store = createStoreWithPrefs()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)
            store.acceptLiveDownload(live, record)
            live.complete()
            flushHistory(store)
            compare(JSON.parse(store.preferencesStore.getDownloadHistoryRaw() || "[]").length, 1)

            store.clearDownloadHistory()
            compare(store.downloadModel.length, 0)
            compare(store.downloadStripModel.length, 0)
            compare(JSON.parse(store.preferencesStore.getDownloadHistoryRaw() || "[]").length, 0)
        }

        // --- Download Pill strip (session-only; issue 03) ---

        function test_strip_addDownload_appearsInStrip() {
            const store = createStore()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)

            verify(Array.isArray(store.downloadStripModel))
            compare(store.downloadStripModel.length, 1)
            compare(store.downloadStripModel[0], record)
            compare(store.getStripDownload(0), record)
        }

        function test_strip_newDownload_prependsNewestFirst() {
            const store = createStore()
            const live1 = createTemporaryObject(fakeDownloadComponent, root)
            live1.downloadFileName = "older.pdf"
            const live2 = createTemporaryObject(fakeDownloadComponent, root)
            live2.downloadFileName = "newer.pdf"
            const older = store.addDownload(live1)
            const newer = store.addDownload(live2)

            compare(store.downloadStripModel.length, 2)
            compare(store.downloadStripModel[0], newer)
            compare(store.downloadStripModel[1], older)
            compare(store.getStripDownload(0), newer)
        }

        function test_strip_restoreHistory_doesNotPopulateStrip() {
            const prefs = createTemporaryObject(fakePreferencesComponent, root)
            prefs.setDownloadHistoryRaw(JSON.stringify([{
                url: "https://example.com/old.bin",
                fileName: "old.bin",
                downloadDirectory: "/tmp/status-downloads",
                mimeType: "application/octet-stream",
                isInline: false,
                startTime: new Date().toISOString(),
                state: AbstractWebView.DownloadState.DownloadCompleted,
                totalBytes: 10,
                errorString: ""
            }]))

            const store = createStore()
            store.preferencesStore = prefs
            store.pathExistsFn = function(path) { return false }
            store.restoreDownloadHistory()

            compare(store.downloadModel.length, 1)
            compare(store.downloadStripModel.length, 0)
        }

        function test_strip_dismissFromStrip_removesOnlyFromStrip() {
            const store = createStore()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)
            live.complete()

            compare(store.downloadStripModel.length, 1)
            store.dismissFromStrip(0)

            compare(store.downloadStripModel.length, 0)
            compare(store.downloadModel.length, 1)
            compare(store.getDownload(0), record)
        }

        function test_strip_dismissRecord_byIdentity() {
            const store = createStore()
            const live1 = createTemporaryObject(fakeDownloadComponent, root)
            live1.downloadFileName = "a.pdf"
            const live2 = createTemporaryObject(fakeDownloadComponent, root)
            live2.downloadFileName = "b.pdf"
            const a = store.addDownload(live1)
            const b = store.addDownload(live2)
            // Strip is newest-first: [b, a]
            compare(store.downloadStripModel[0], b)
            compare(store.downloadStripModel[1], a)

            store.dismissRecordFromStrip(a)

            compare(store.downloadStripModel.length, 1)
            compare(store.downloadStripModel[0], b)
            compare(store.downloadModel.length, 2)
        }

        // --- Downloads List policy (issue 05): Missing File, retry, open, share ---

        function test_reattachForRetry_keepsIdentity_andMovesNewest() {
            const store = createStore()
            const otherLive = createTemporaryObject(fakeDownloadComponent, root)
            otherLive.downloadFileName = "other.bin"
            otherLive.url = "https://example.com/other.bin"
            const other = store.addDownload(otherLive)

            const cancelledLive = createTemporaryObject(fakeDownloadComponent, root)
            cancelledLive.downloadFileName = "clip.webm"
            cancelledLive.url = "https://example.com/clip.webm"
            const record = store.addDownload(cancelledLive)
            cancelledLive.cancel()
            compare(record.state, AbstractWebView.DownloadState.DownloadCancelled)
            compare(store.downloadModel.length, 2)

            const retryLive = createTemporaryObject(fakeDownloadComponent, root)
            retryLive.downloadFileName = "clip.webm"
            retryLive.url = "https://example.com/clip.webm"
            retryLive.state = AbstractWebView.DownloadState.DownloadInProgress
            const reused = store.reattachForRetry(record, retryLive, null)
            store.acceptLiveDownload(retryLive, reused)

            compare(reused, record)
            compare(store.downloadModel.length, 2)
            compare(store.downloadModel[0], other)
            compare(store.downloadModel[1], record)
            compare(store.downloadStripModel[0], record)
            compare(record.liveDownload, retryLive)
            compare(record.state, AbstractWebView.DownloadState.DownloadInProgress)
            compare(store.downloadsListModel[0], record)
        }

        function test_downloadsList_newestFirst() {
            const store = createStore()
            const live1 = createTemporaryObject(fakeDownloadComponent, root)
            live1.downloadFileName = "old.bin"
            const live2 = createTemporaryObject(fakeDownloadComponent, root)
            live2.downloadFileName = "new.bin"
            store.addDownload(live1)
            store.addDownload(live2)

            const list = store.downloadsListNewestFirst()
            compare(list, store.downloadsListModel)
            compare(list.length, 2)
            compare(list[0].fileName, "new.bin")
            compare(list[1].fileName, "old.bin")
            // Underlying History order unchanged (oldest first for cap eviction).
            compare(store.downloadModel[0].fileName, "old.bin")
        }

        function test_missingFile_lazyProbe_setsFlagOnCompleted() {
            const store = createStore()
            store.pathExistsFn = function(path) {
                return path !== "/tmp/downloads/gone.pdf"
            }
            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.downloadFileName = "gone.pdf"
            live.downloadDirectory = "/tmp/downloads"
            const record = store.addDownload(live)
            live.complete()

            compare(record.missingFile, false)
            store.refreshMissingFiles()
            compare(record.missingFile, true)
        }

        function test_missingFile_notFlaggedWhileInProgress() {
            const store = createStore()
            store.pathExistsFn = function(path) { return false }
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)
            live.advance(10)

            store.refreshMissingFiles()
            compare(record.missingFile, false)
        }

        function test_retryEligibility_menuAndTap_rules() {
            const store = createStore()

            const interrupted = createTemporaryObject(fakeDownloadComponent, root)
            const interruptedRec = store.addDownload(interrupted)
            interruptedRec.state = AbstractWebView.DownloadState.DownloadInterrupted
            interruptedRec.isInline = false

            const cancelled = createTemporaryObject(fakeDownloadComponent, root)
            const cancelledRec = store.addDownload(cancelled)
            cancelledRec.state = AbstractWebView.DownloadState.DownloadCancelled
            cancelledRec.isInline = false

            const inlineInterrupted = createTemporaryObject(fakeDownloadComponent, root)
            const inlineRec = store.addDownload(inlineInterrupted)
            inlineRec.state = AbstractWebView.DownloadState.DownloadInterrupted
            inlineRec.isInline = true

            const completed = createTemporaryObject(fakeDownloadComponent, root)
            const completedRec = store.addDownload(completed)
            completed.complete()

            verify(store.canRetryFromMenu(interruptedRec))
            verify(store.canRetryFromTap(interruptedRec))
            verify(store.canRetryFromMenu(cancelledRec))
            verify(!store.canRetryFromTap(cancelledRec))
            verify(!store.canRetryFromMenu(inlineRec))
            verify(!store.canRetryFromTap(inlineRec))
            verify(!store.canRetryFromMenu(completedRec))
            verify(!store.canRetryFromTap(completedRec))
        }

        function test_canOpenInBrowser_allowlist_andPdfGate() {
            const store = createStore()

            const png = createTemporaryObject(fakeDownloadComponent, root)
            png.mimeType = "image/png"
            png.downloadFileName = "a.png"
            const pngRec = store.addDownload(png)
            png.complete()

            const pdf = createTemporaryObject(fakeDownloadComponent, root)
            pdf.mimeType = "application/pdf"
            pdf.downloadFileName = "a.pdf"
            const pdfRec = store.addDownload(pdf)
            pdf.complete()

            const bin = createTemporaryObject(fakeDownloadComponent, root)
            bin.mimeType = "application/octet-stream"
            bin.downloadFileName = "a.bin"
            const binRec = store.addDownload(bin)
            bin.complete()

            verify(store.canOpenInBrowser(pngRec, false))
            verify(!store.canOpenInBrowser(pdfRec, false))
            verify(store.canOpenInBrowser(pdfRec, true))
            verify(!store.canOpenInBrowser(binRec, true))
            pngRec.missingFile = true
            verify(!store.canOpenInBrowser(pngRec, false))
        }

        function test_canOpenInBrowser_mediaAllowlist_andExclusions() {
            const store = createStore()

            function completed(mime, name) {
                const live = createTemporaryObject(fakeDownloadComponent, root)
                live.mimeType = mime
                live.downloadFileName = name
                live.suggestedFileName = name
                const rec = store.addDownload(live)
                live.complete()
                return rec
            }

            verify(store.canOpenInBrowser(completed("audio/mpeg", "a.mp3"), false))
            verify(store.canOpenInBrowser(completed("audio/wav", "a.wav"), false))
            verify(store.canOpenInBrowser(completed("video/webm", "a.webm"), false))

            // No proprietary codecs in the shipped Chromium: H.264/AAC would load a
            // player that cannot decode, so they go to the OS like Ogg and Matroska.
            verify(!store.canOpenInBrowser(completed("audio/mp4", "a.m4a"), true))
            verify(!store.canOpenInBrowser(completed("audio/aac", "a.aac"), true))
            verify(!store.canOpenInBrowser(completed("video/mp4", "a.mp4"), true))
            verify(!store.canOpenInBrowser(completed("audio/ogg", "a.ogg"), true))
            verify(!store.canOpenInBrowser(completed("video/x-matroska", "a.mkv"), true))
        }

        function test_mediaPlayerPage_writesPlayerForMedia_reusesPerTarget() {
            const store = createStore()
            store.downloadsDirectory = "/tmp/status-downloads"
            store.pathExistsFn = function(path) { return false }
            store.mediaPlayerDirectory = "/tmp/status-player"

            let written = null
            store.writeTextFileFn = function(path, data) {
                written = { path: path, data: data }
                return true
            }

            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.mimeType = "video/webm"
            live.downloadFileName = "sample 30s (2).webm"
            live.suggestedFileName = live.downloadFileName
            const rec = store.addDownload(live)
            live.complete()

            verify(store.isPlayableMedia(rec))
            const url = String(store.mediaPlayerPageUrl(rec))
            verify(url.startsWith("file:///tmp/status-player/player-"))
            verify(url.endsWith(".html"))

            verify(!!written)
            verify(written.data.indexOf("<video ") >= 0)
            verify(written.data.indexOf("<audio ") < 0)
            // Spaces are percent-encoded — a raw space would break the src.
            verify(written.data.indexOf('src="file:///') >= 0)
            verify(written.data.indexOf("sample%2030s%20(2).webm") >= 0)
            verify(written.data.indexOf('.webm" controls') >= 0)

            // Replaying the same target reuses one page instead of piling up temp files.
            written = null
            compare(String(store.mediaPlayerPageUrl(rec)), url)
            verify(!!written)
            compare(written.path, "/tmp/status-player/player-" + url.split("player-")[1].replace(".html", "") + ".html")
        }

        function test_isBrowsableLocalUrl_onlyPlayerPagesAndOwnTargets() {
            const store = createStore()
            store.downloadsDirectory = "/tmp/status-downloads"
            store.pathExistsFn = function(path) { return false }
            store.mediaPlayerDirectory = "/tmp/status-player"
            store.writeTextFileFn = function(path, data) { return true }

            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.mimeType = "video/webm"
            live.downloadFileName = "clip 1.webm"
            live.suggestedFileName = live.downloadFileName
            const rec = store.addDownload(live)
            live.complete()

            verify(store.isBrowsableLocalUrl(store.mediaPlayerPageUrl(rec)))

            // The Record's own Download Target, percent-encoded as WebEngine reports it.
            const target = String(rec.targetPath)
            verify(target.indexOf("clip 1.webm") > 0)
            verify(store.isBrowsableLocalUrl(
                       "file://" + target.split("/").map(encodeURIComponent).join("/")))

            // Anything else local stays blocked by the Backend guard.
            verify(!store.isBrowsableLocalUrl("file:///etc/passwd"))
            verify(!store.isBrowsableLocalUrl("file:///tmp/status-player/evil.html"))
            verify(!store.isBrowsableLocalUrl(
                       "file://" + target.replace("clip 1.webm", "other.webm")))
            verify(!store.isBrowsableLocalUrl("https://example.com/clip.webm"))
            verify(!store.isBrowsableLocalUrl(""))
        }

        function test_mediaPlayerPage_audioTag_andEmptyWhenUnusable() {
            const store = createStore()
            store.mediaPlayerDirectory = "/tmp/status-player"

            let data = ""
            store.writeTextFileFn = function(path, text) { data = text; return true }

            function completed(mime, name) {
                const live = createTemporaryObject(fakeDownloadComponent, root)
                live.mimeType = mime
                live.downloadFileName = name
                live.suggestedFileName = name
                const rec = store.addDownload(live)
                live.complete()
                return rec
            }

            const mp3 = completed("audio/mpeg", "tune.mp3")
            verify(String(store.mediaPlayerPageUrl(mp3)).length > 0)
            verify(data.indexOf("<audio ") >= 0)
            verify(data.indexOf("<video ") < 0)
            // The name is shown — an audio page is otherwise an empty void.
            verify(data.indexOf("tune.mp3") >= 0)
            // A codec the build lacks must say so instead of leaving a dead control.
            verify(data.indexOf('id="failed"') >= 0)
            // Assets came from media_player.html/.js, fully substituted.
            verify(data.indexOf("min(90%, 520px)") >= 0)
            verify(data.indexOf('addEventListener("error"') >= 0)
            verify(data.indexOf("__") < 0)

            // Non-media never gets a page — it navigates to the file directly.
            compare(String(store.mediaPlayerPageUrl(completed("application/pdf", "a.pdf"))), "")

            // A failed write leaves the caller to fall back to the OS handler.
            store.writeTextFileFn = function() { return false }
            compare(String(store.mediaPlayerPageUrl(completed("video/webm", "clip.webm"))), "")

            // Missing file blocks both routes.
            store.writeTextFileFn = function(path, text) { return true }
            const gone = completed("video/webm", "gone.webm")
            gone.missingFile = true
            compare(String(store.mediaPlayerPageUrl(gone)), "")

            // An unreadable page asset must not write a half-built page.
            let written = false
            store.writeTextFileFn = function(path, text) { written = true; return true }
            store._mediaPlayerTemplateCache = ""
            store.readTextFileFn = function(path) { return "" }
            compare(String(store.mediaPlayerPageUrl(completed("audio/mpeg", "b.mp3"))), "")
            verify(!written)
        }

        function test_canShareFile_requiresCompletedPresentFile() {
            const store = createStore()
            store.pathExistsFn = function(path) { return true }
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)
            live.complete()
            store.refreshMissingFiles()

            verify(store.canShareFile(record))
            record.missingFile = true
            verify(!store.canShareFile(record))
        }

        function test_shareFile_invokesSharePathsFn() {
            const store = createStore()
            store.preferShareSheet = true
            let shared = []
            store.sharePathsFn = function(paths) { shared = paths.slice() }
            store.pathExistsFn = function(path) { return true }

            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.downloadDirectory = "/tmp/downloads"
            live.downloadFileName = "report.pdf"
            const record = store.addDownload(live)
            live.complete()
            store.refreshMissingFiles()

            verify(store.shareFile(record))
            compare(shared.length, 1)
            compare(shared[0], "/tmp/downloads/report.pdf")
        }

        function test_shareFile_desktop_copiesPath() {
            const store = createStore()
            store.preferShareSheet = false
            let copied = ""
            let shared = []
            store.copyTextFn = function(text) { copied = text }
            store.sharePathsFn = function(paths) { shared = paths.slice() }
            store.pathExistsFn = function(path) { return true }

            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.downloadDirectory = "/tmp/downloads"
            live.downloadFileName = "report.pdf"
            const record = store.addDownload(live)
            live.complete()
            store.refreshMissingFiles()

            verify(store.shareFile(record))
            compare(copied, "/tmp/downloads/report.pdf")
            compare(shared.length, 0)
        }

        function test_shareUrl_mobile_usesShareText_desktop_copies() {
            const store = createStore()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.url = "https://example.com/report.pdf"
            const record = store.addDownload(live)

            store.preferShareSheet = true
            let sharedText = ""
            store.shareTextFn = function(text) { sharedText = text }
            verify(store.shareUrl(record))
            compare(sharedText, "https://example.com/report.pdf")

            store.preferShareSheet = false
            let copied = ""
            store.copyTextFn = function(text) { copied = text }
            verify(store.shareUrl(record))
            compare(copied, "https://example.com/report.pdf")
        }

        function test_canShowInFolder_desktopAndroid_notIos() {
            const store = createStore()
            store.pathExistsFn = function(path) { return true }
            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)
            live.complete()
            store.refreshMissingFiles()

            store.showInFolderSupported = true
            verify(store.canShowInFolder(record))
            store.showInFolderSupported = false
            verify(!store.canShowInFolder(record))
            store.showInFolderSupported = true
            record.missingFile = true
            verify(!store.canShowInFolder(record))
        }

        function test_openDirectoryForRecord_callsShowInFolderFn_withTargetPath() {
            const store = createStore()
            store.pathExistsFn = function(path) { return true }
            store.showInFolderSupported = true
            let shownPath = ""
            store.showInFolderFn = function(path) { shownPath = path }

            const live = createTemporaryObject(fakeDownloadComponent, root)
            const record = store.addDownload(live)
            live.complete()
            store.refreshMissingFiles()

            store.openDirectoryForRecord(record)
            compare(shownPath, record.targetPath)

            // iOS / unsupported: no-op
            shownPath = "unchanged"
            store.showInFolderSupported = false
            store.openDirectoryForRecord(record)
            compare(shownPath, "unchanged")
        }

        function test_canShowInFolder_incognitoCompleted_stillAllowed() {
            // ADR 0006: Incognito Records stay session-only and are not registered
            // with the Android Downloads UI, but Show in folder remains available
            // for the on-disk file (Desktop reveal / Android Downloads app).
            const store = createStore()
            store.pathExistsFn = function(path) { return true }
            store.showInFolderSupported = true
            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.offTheRecord = true
            const record = store.addDownload(live)
            live.complete()
            store.refreshMissingFiles()
            verify(!!record.offTheRecord)
            verify(store.canShowInFolder(record))
        }

        function test_sourceUrl_forShareCopy() {
            const store = createStore()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.url = "https://example.com/report.pdf"
            const record = store.addDownload(live)

            compare(store.sourceUrlString(record), "https://example.com/report.pdf")
            verify(store.canShareUrl(record))
            record.missingFile = true
            verify(store.canShareUrl(record)) // URL actions remain for Missing File
        }

        function test_statusText_oneWordingPerState() {
            const store = createStore()
            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.receivedBytes = 400
            live.totalBytes = 1000
            const record = store.addDownload(live)

            verify(store.statusText(record).indexOf("/") >= 0)

            live.pause()
            verify(store.statusText(record).indexOf("/") >= 0)
            verify(store.statusText(record).indexOf("Paused") < 0)

            live.complete()
            compare(store.statusText(record), "")

            record.missingFile = true
            compare(store.statusText(record), "Missing file")

            record.missingFile = false
            record.state = AbstractWebView.DownloadState.DownloadInterrupted
            compare(store.statusText(record), "Interrupted")

            record.state = AbstractWebView.DownloadState.DownloadCancelled
            compare(store.statusText(record), "Canceled")
        }

        function test_shareFile_desktop_copiesBareFilesystemPath() {
            const store = createStore()
            store.preferShareSheet = false
            let copied = ""
            store.copyTextFn = function(text) { copied = text }
            store.pathExistsFn = function(path) { return true }

            const live = createTemporaryObject(fakeDownloadComponent, root)
            live.downloadDirectory = "/tmp/downloads"
            live.downloadFileName = "song.mp3"
            const record = store.addDownload(live)
            live.complete()
            store.refreshMissingFiles()

            verify(store.shareFile(record))
            compare(copied, "/tmp/downloads/song.mp3")
            verify(!copied.startsWith("file:"))
        }

        // ADR 0006 §6 / issue 06 — Retained View ownership seam
        function test_viewHasNonTerminalDownloads_tracksOriginatingView() {
            const store = createStore()
            const viewA = createTemporaryObject(fakeViewComponent, root)
            const viewB = createTemporaryObject(fakeViewComponent, root)
            const live = createTemporaryObject(fakeDownloadComponent, root)

            verify(!store.viewHasNonTerminalDownloads(viewA))

            const record = store.addDownload(live, viewA)
            compare(record.originatingView, viewA)
            verify(store.viewHasNonTerminalDownloads(viewA))
            verify(!store.viewHasNonTerminalDownloads(viewB))
            verify(!store.viewHasNonTerminalDownloads(null))

            live.complete()
            verify(!store.viewHasNonTerminalDownloads(viewA))
        }

        function test_viewDownloadsCleared_emitsWhenLastNonTerminalEnds() {
            const store = createStore()
            const view = createTemporaryObject(fakeViewComponent, root)
            const live1 = createTemporaryObject(fakeDownloadComponent, root)
            const live2 = createTemporaryObject(fakeDownloadComponent, root)
            live2.downloadFileName = "other.bin"
            live2.suggestedFileName = "other.bin"
            live2.destinationPath = "/tmp/downloads/other.bin"

            let clearedCount = 0
            let clearedView = null
            store.viewDownloadsCleared.connect(function(v) {
                clearedCount += 1
                clearedView = v
            })

            const r1 = store.addDownload(live1, view)
            const r2 = store.addDownload(live2, view)
            verify(store.viewHasNonTerminalDownloads(view))

            live1.complete()
            compare(clearedCount, 0)
            verify(store.viewHasNonTerminalDownloads(view))

            live2.complete()
            compare(clearedCount, 1)
            compare(clearedView, view)
            verify(!store.viewHasNonTerminalDownloads(view))
            verify(r1.isTerminal && r2.isTerminal)
        }

        function test_addDownload_stampsOffTheRecord_fromHostView() {
            const store = createStore()
            const view = createTemporaryObject(fakeViewComponent, root)
            view.offTheRecord = true
            const live = createTemporaryObject(fakeMobileDownloadComponent, root)
            // Mobile download has no offTheRecord / view — host view is the source of truth.
            const record = store.addDownload(live, view)
            verify(record.offTheRecord)
            compare(record.originatingView, view)
        }

        function test_viewDownloadsCleared_notEmittedForUnrelatedView() {
            const store = createStore()
            const viewA = createTemporaryObject(fakeViewComponent, root)
            const viewB = createTemporaryObject(fakeViewComponent, root)
            const liveA = createTemporaryObject(fakeDownloadComponent, root)
            const liveB = createTemporaryObject(fakeDownloadComponent, root)
            liveB.downloadFileName = "b.bin"
            liveB.suggestedFileName = "b.bin"
            liveB.destinationPath = "/tmp/downloads/b.bin"

            let clearedViews = []
            store.viewDownloadsCleared.connect(function(v) {
                clearedViews.push(v)
            })

            store.addDownload(liveA, viewA)
            store.addDownload(liveB, viewB)
            liveA.complete()

            compare(clearedViews.length, 1)
            compare(clearedViews[0], viewA)
            verify(store.viewHasNonTerminalDownloads(viewB))
        }
    }
}
