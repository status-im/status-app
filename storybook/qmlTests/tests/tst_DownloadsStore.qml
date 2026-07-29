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
            property string errorString: ""
            property string destinationPath: downloadDirectory + "/" + downloadFileName
            property bool accepted: false

            function accept() { accepted = true }
            function cancel() {
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

    TestCase {
        name: "DownloadsStore"
        when: windowShown

        function createStore() {
            const component = Qt.createComponent(root.downloadsStoreUrl)
            verify(component.status === Component.Ready, component.errorString())
            return createTemporaryObject(component, root)
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
            compare(JSON.parse(store.preferencesStore.getDownloadHistoryRaw() || "[]").length, 0)
        }
    }
}
