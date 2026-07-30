import QtCore
import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils

import utils

import AppLayouts.Browser.adapters

/**
 * Owns Download Records for the browser (see Browser CONTEXT / ADR 0006).
 * Live Backend downloads attach to Records; the list identity is the Record.
 * Download History persists via preferencesStore (create + terminal only).
 *
 * downloadModel is a JS array of DownloadRecord objects (not ObjectModel):
 * ObjectModel treats entries as visual QQuickItems and crashes ListView.
 */
QtObject {
    id: root

    // Array of DownloadRecord; reassigned on change so ListView refreshes.
    property var downloadModel: []

    // Session-only Download Pill strip. Never restored from Download History (ADR 0006 / issue 03).
    property var downloadStripModel: []

    // Browser preferences (same mechanism as Tab Session). Optional in unit tests.
    property var preferencesStore: null

    property int historyCap: 200
    property int historySaveDebounceMs: 700

    // Host Download Target policy: platform downloads location (overridable in tests).
    property string downloadsDirectory: {
        const loc = StandardPaths.writableLocation(StandardPaths.DownloadLocation)
        return loc ? String(loc).replace("file://", "") : ""
    }

    // Disk existence probe; production uses SystemUtils.fileExists, tests inject a fake.
    property var pathExistsFn: function(path) {
        return SystemUtils.fileExists(path)
    }

    // Directory create; injectable so Storybook/unit tests need not stub SystemUtils.
    property var ensureDirectoryFn: function(path) {
        return SystemUtils.ensureDirectory(path)
    }

    // Mobile share sheet for files; production uses SystemUtils.sharePaths, tests inject a fake.
    property var sharePathsFn: function(paths) {
        SystemUtils.sharePaths(paths)
    }

    // Mobile share sheet for text/URL; production uses ShareUtils.shareText.
    property var shareTextFn: function(text) {
        ShareUtils.shareText(text)
    }

    // Desktop Copy file / Copy URL; production uses ClipboardUtils.
    property var copyTextFn: function(text) {
        ClipboardUtils.setText(text)
    }

    // Mobile → share sheet; desktop → copy. Injectable for QML tests.
    property bool preferShareSheet: SQUtils.Utils.isMobile

    // Show in folder: Desktop + Android; hidden on iOS (ADR 0006 / UX 02 / UX 06).
    property bool showInFolderSupported: !SQUtils.Utils.isIOS

    // Desktop reveals file; Android opens system Downloads UI. Injectable for QML tests.
    property var showInFolderFn: function(path) {
        SystemUtils.showInFolder(path)
    }

    readonly property url _downloadRecordUrl: Qt.resolvedUrl("DownloadRecord.qml")

    /// Emitted when a host Web View no longer owns any non-terminal Downloads.
    /// BrowserWebViewContext destroys Retained Views on this signal (ADR 0006 §6).
    signal viewDownloadsCleared(var view)

    readonly property Timer _historySaveTimer: Timer {
        interval: Math.max(0, root.historySaveDebounceMs)
        repeat: false
        onTriggered: root.saveDownloadHistoryNow()
    }

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

    /// hostView is the host Web View (LazyWebViewAdapter) that owns this Download.
    /// Required for Retained View ownership; Backend download.view is unreliable on mobile.
    function addDownload(download, hostView) {
        const component = Qt.createComponent(_downloadRecordUrl)
        if (component.status !== Component.Ready) {
            console.error("DownloadsStore: failed to load DownloadRecord:", component.errorString())
            return null
        }
        const record = component.createObject(root)
        record.attach(download)
        if (hostView)
            record.originatingView = hostView
        else if (download && download.view)
            record.originatingView = download.view

        if (hostView && hostView.offTheRecord !== undefined)
            record.offTheRecord = !!hostView.offTheRecord
        else if (download) {
            if (download.offTheRecord !== undefined)
                record.offTheRecord = !!download.offTheRecord
            else if (download.view && download.view.offTheRecord !== undefined)
                record.offTheRecord = !!download.view.offTheRecord
        }
        record.terminalReached.connect(function() {
            root.scheduleSaveDownloadHistory()
            root._maybeEmitViewDownloadsCleared(record.originatingView)
        })
        downloadModel = downloadModel.concat([record])
        downloadStripModel = downloadStripModel.concat([record])
        root.enforceHistoryCap()
        root.scheduleSaveDownloadHistory()
        return record
    }

    /// True while any Download Record for this host Web View is still non-terminal.
    function viewHasNonTerminalDownloads(view) {
        if (!view)
            return false
        for (let i = 0; i < downloadModel.length; ++i) {
            const record = downloadModel[i]
            if (!record || record.originatingView !== view)
                continue
            // Read state via isTerminalState — isTerminal can lag behind
            // onStateChanged when called from a terminalReached handler.
            if (record.isTerminalState) {
                if (!record.isTerminalState(record.state))
                    return true
            } else if (!record.isTerminal) {
                return true
            }
        }
        return false
    }

    function _maybeEmitViewDownloadsCleared(view) {
        if (!view)
            return
        if (!root.viewHasNonTerminalDownloads(view))
            root.viewDownloadsCleared(view)
    }

    /// Remove a Record from the Download Pill strip only (History / downloadModel unchanged).
    function dismissFromStrip(index) {
        if (index < 0 || index >= downloadStripModel.length)
            return
        const next = downloadStripModel.slice()
        next.splice(index, 1)
        downloadStripModel = next
    }

    function dismissRecordFromStrip(record) {
        if (!record)
            return
        for (let i = 0; i < downloadStripModel.length; ++i) {
            if (downloadStripModel[i] === record) {
                dismissFromStrip(i)
                return
            }
        }
    }

    function clearDownloadStrip() {
        downloadStripModel = []
    }

    function openFile(index) {
        openRecord(getDownload(index))
    }

    function openRecord(record) {
        if (!record || record.missingFile)
            return
        Qt.openUrlExternally(UrlUtils.urlFromUserInput(record.targetPath))
    }

    function openDirectory(index) {
        openDirectoryForRecord(getDownload(index))
    }

    function openDirectoryForRecord(record) {
        if (!record || !canShowInFolder(record))
            return
        // Prefer the file path so desktop can reveal/select it; Android opens
        // the system Downloads UI and ignores the path (UX 06).
        const path = record.targetPath || record.downloadDirectory
        if (!path)
            return
        root.showInFolderFn(path)
    }

    /// Newest Download Records first for the Downloads List UI (History stays oldest-first).
    function downloadsListNewestFirst() {
        const list = []
        for (let i = downloadModel.length - 1; i >= 0; --i)
            list.push(downloadModel[i])
        return list
    }

    /// Lazy Missing File probe for Completed Records (list shown / app foreground).
    function refreshMissingFiles() {
        for (let i = 0; i < downloadModel.length; ++i) {
            const record = downloadModel[i]
            if (!record)
                continue
            if (record.state !== AbstractWebView.DownloadState.DownloadCompleted) {
                record.missingFile = false
                continue
            }
            const path = record.targetPath
            record.missingFile = !(path && root.pathExistsFn && root.pathExistsFn(path))
        }
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

    function canShareFile(record) {
        if (!record || record.missingFile)
            return false
        return record.state === AbstractWebView.DownloadState.DownloadCompleted
            && !!record.targetPath
    }

    function canShowInFolder(record) {
        if (!root.showInFolderSupported || !record || record.missingFile)
            return false
        return record.state === AbstractWebView.DownloadState.DownloadCompleted
            && !!record.targetPath
    }

    function canShareUrl(record) {
        return !!record && sourceUrlString(record).length > 0
    }

    function sourceUrlString(record) {
        if (!record || record.url === undefined || record.url === null)
            return ""
        return String(record.url)
    }

    /// Open-in-Browser allowlist: images, plain text, HTML; PDF only when Backend supports it.
    function canOpenInBrowser(record, supportsPdf) {
        if (!record || record.missingFile)
            return false
        if (record.state !== AbstractWebView.DownloadState.DownloadCompleted)
            return false

        const mime = String(record.mimeType || "").toLowerCase()
        const name = String(record.fileName || "").toLowerCase()

        if (mime.startsWith("image/") || /\.(png|jpe?g|gif|webp|bmp|svg)$/.test(name))
            return true
        if (mime === "text/plain" || mime === "text/html" || mime === "application/xhtml+xml"
                || /\.(txt|html?|xhtml)$/.test(name))
            return true
        if (mime === "application/pdf" || name.endsWith(".pdf"))
            return !!supportsPdf
        return false
    }

    /// Mobile: system share sheet. Desktop: copy the Download Target path.
    function shareFile(record) {
        if (!canShareFile(record))
            return false
        const path = record.targetPath
        if (root.preferShareSheet) {
            if (root.sharePathsFn)
                root.sharePathsFn([path])
        } else if (root.copyTextFn) {
            root.copyTextFn(path)
        }
        return true
    }

    /// Mobile: system share sheet. Desktop: copy the source URL.
    function shareUrl(record) {
        const url = sourceUrlString(record)
        if (!url)
            return false
        if (root.preferShareSheet) {
            if (root.shareTextFn)
                root.shareTextFn(url)
        } else if (root.copyTextFn) {
            root.copyTextFn(url)
        }
        return true
    }

    /// Middle-elide the base name, then keep the extension (pill + list).
    function elideFileName(fileName, maxLength) {
        if (!fileName)
            return ""
        const s = String(fileName)
        const limit = Number(maxLength)
        if (!(limit > 0) || s.length <= limit)
            return s

        const lastDot = s.lastIndexOf(".")
        if (lastDot <= 0) {
            if (limit <= 1)
                return "…"
            return s.substring(0, limit - 1) + "…"
        }

        const ext = s.substring(lastDot)
        const base = s.substring(0, lastDot)
        const budget = limit - ext.length
        if (budget <= 1) {
            if (ext.length >= limit)
                return s.substring(0, Math.max(0, limit - 1)) + "…"
            return "…" + ext
        }
        if (base.length <= budget)
            return base + ext

        const keep = budget - 1
        const head = Math.ceil(keep / 2)
        const tail = Math.floor(keep / 2)
        return base.substring(0, head) + "…" + base.substring(base.length - tail) + ext
    }

    /// Shared subtitle for Downloads List / Download Pill.
    function statusText(record) {
        if (!record)
            return ""
        if (record.missingFile)
            return qsTr("Missing file")
        const state = record.state
        if (state === AbstractWebView.DownloadState.DownloadCompleted)
            return qsTr("Completed")
        if (state === AbstractWebView.DownloadState.DownloadCancelled)
            return qsTr("Canceled")
        if (state === AbstractWebView.DownloadState.DownloadInterrupted)
            return qsTr("Interrupted — tap to retry")
        if (state === AbstractWebView.DownloadState.DownloadPaused || record.isPaused)
            return qsTr("Paused")
        if (state === AbstractWebView.DownloadState.DownloadInProgress
                || state === AbstractWebView.DownloadState.DownloadRequested) {
            const received = record.receivedBytes ?? 0
            const total = record.totalBytes ?? 0
            if (total > 0) {
                return "%1/%2"
                    .arg(Qt.locale().formattedDataSize(received, 2, Locale.DataSizeTraditionalFormat))
                    .arg(Qt.locale().formattedDataSize(total, 2, Locale.DataSizeTraditionalFormat))
            }
            return Qt.locale().formattedDataSize(received, 2, Locale.DataSizeTraditionalFormat)
        }
        return ""
    }

    /// Sanitize a suggested file name and resolve a free Download Target under downloadsDirectory.
    /// Collisions with existing files or in-session Records get "(1)", "(2)", … suffixes.
    function resolveDownloadTarget(suggestedFileName) {
        const dir = root.downloadsDirectory.replace(/[/\\]+$/, "")
        if (root.ensureDirectoryFn)
            root.ensureDirectoryFn(dir)

        let name = String(suggestedFileName || "").trim()
        if (!name)
            name = "download.bin"
        name = name.replace(/[\\/]/g, "_")

        let candidate = joinPath(dir, name)
        let n = 1
        while (pathTaken(candidate)) {
            candidate = joinPath(dir, withCollisionSuffix(name, n))
            n += 1
            if (n > 1000)
                break
        }
        return candidate
    }

    /// Accept the live Backend download into a resolved Download Target and update the Record.
    /// Mobile-shaped: accept(path). WebEngine-shaped: set downloadDirectory/fileName then accept().
    function acceptLiveDownload(download, record) {
        if (!download)
            return ""

        const suggested = download.suggestedFileName || download.downloadFileName || "download.bin"
        const target = resolveDownloadTarget(suggested)
        const parts = splitPath(target)

        if (record) {
            record.downloadDirectory = parts.dir
            record.fileName = parts.fileName
        }

        if (download.downloadDirectory !== undefined) {
            // WebEngineDownloadRequest
            download.downloadDirectory = parts.dir
            download.downloadFileName = parts.fileName
            download.accept()
        } else {
            // MobileWebViewDownload
            download.accept(target)
        }

        if (record)
            record.syncFromLive()

        return target
    }

    function scheduleSaveDownloadHistory() {
        if (!preferencesStore)
            return
        if (historySaveDebounceMs <= 0) {
            saveDownloadHistoryNow()
            return
        }
        _historySaveTimer.restart()
    }

    function saveDownloadHistoryNow() {
        if (!preferencesStore || !preferencesStore.setDownloadHistoryRaw)
            return

        let persistable = []
        for (let i = 0; i < downloadModel.length; ++i) {
            const record = downloadModel[i]
            if (!record || record.offTheRecord)
                continue
            persistable.push(serializeRecord(record))
        }
        if (persistable.length > historyCap)
            persistable = persistable.slice(persistable.length - historyCap)

        preferencesStore.setDownloadHistoryRaw(JSON.stringify(persistable))
    }

    function restoreDownloadHistory() {
        if (!preferencesStore || !preferencesStore.getDownloadHistoryRaw)
            return

        const raw = preferencesStore.getDownloadHistoryRaw()
        if (!raw)
            return

        let parsed = []
        try {
            parsed = JSON.parse(raw)
        } catch (e) {
            console.warn("DownloadsStore: invalid Download History JSON")
            return
        }
        if (!Array.isArray(parsed))
            return

        const component = Qt.createComponent(_downloadRecordUrl)
        if (component.status !== Component.Ready) {
            console.error("DownloadsStore: failed to load DownloadRecord:", component.errorString())
            return
        }

        const restored = []
        for (let i = 0; i < parsed.length; ++i) {
            const dto = parsed[i]
            if (!dto)
                continue
            const record = component.createObject(root)
            applyDto(record, dto)
            if (!record.isTerminal) {
                record.state = AbstractWebView.DownloadState.DownloadInterrupted
                record.isPaused = false
            }
            record.terminalReached.connect(function() {
                root.scheduleSaveDownloadHistory()
            })
            restored.push(record)
        }
        downloadModel = restored
        enforceHistoryCap()
    }

    /// Clear Download History Records only — files on disk are left alone (ADR 0006).
    function clearDownloadHistory() {
        downloadModel = []
        downloadStripModel = []
        if (preferencesStore && preferencesStore.clearDownloadHistoryRaw)
            preferencesStore.clearDownloadHistoryRaw()
        else if (preferencesStore && preferencesStore.setDownloadHistoryRaw)
            preferencesStore.setDownloadHistoryRaw("[]")
    }

    function enforceHistoryCap() {
        let persistableIndexes = []
        for (let i = 0; i < downloadModel.length; ++i) {
            if (downloadModel[i] && !downloadModel[i].offTheRecord)
                persistableIndexes.push(i)
        }
        if (persistableIndexes.length <= historyCap)
            return

        const removeCount = persistableIndexes.length - historyCap
        const drop = {}
        for (let r = 0; r < removeCount; ++r)
            drop[persistableIndexes[r]] = true

        const next = []
        for (let i = 0; i < downloadModel.length; ++i) {
            if (!drop[i])
                next.push(downloadModel[i])
        }
        downloadModel = next
    }

    function serializeRecord(record) {
        return {
            url: String(record.url || ""),
            fileName: record.fileName || "",
            downloadDirectory: record.downloadDirectory || "",
            mimeType: record.mimeType || "",
            isInline: !!record.isInline,
            startTime: record.startTime instanceof Date
                       ? record.startTime.toISOString()
                       : String(record.startTime || ""),
            state: record.state,
            totalBytes: record.totalBytes,
            errorString: record.errorString || ""
            // receivedBytes intentionally omitted — progress is never persisted
        }
    }

    function applyDto(record, dto) {
        record.url = dto.url || ""
        record.fileName = dto.fileName || ""
        record.downloadDirectory = dto.downloadDirectory || ""
        record.mimeType = dto.mimeType || ""
        record.isInline = !!dto.isInline
        record.startTime = dto.startTime ? new Date(dto.startTime) : new Date()
        record.state = dto.state !== undefined
                      ? dto.state
                      : AbstractWebView.DownloadState.DownloadInterrupted
        record.totalBytes = dto.totalBytes !== undefined ? dto.totalBytes : -1
        record.errorString = dto.errorString || ""
        record.receivedBytes = 0
        record.isPaused = false
        record.offTheRecord = false
        record.liveDownload = null
    }

    function pathTaken(path) {
        if (root.pathExistsFn && root.pathExistsFn(path))
            return true
        for (let i = 0; i < downloadModel.length; ++i) {
            const record = downloadModel[i]
            if (record && record.targetPath === path)
                return true
        }
        return false
    }

    function joinPath(dir, fileName) {
        if (!dir)
            return fileName
        if (dir.endsWith("/") || dir.endsWith("\\"))
            return dir + fileName
        return dir + "/" + fileName
    }

    function splitPath(path) {
        const s = String(path)
        const slash = Math.max(s.lastIndexOf("/"), s.lastIndexOf("\\"))
        if (slash < 0)
            return { dir: "", fileName: s }
        return { dir: s.substring(0, slash), fileName: s.substring(slash + 1) }
    }

    function withCollisionSuffix(fileName, n) {
        const dot = fileName.lastIndexOf(".")
        if (dot <= 0)
            return fileName + " (" + n + ")"
        return fileName.substring(0, dot) + " (" + n + ")" + fileName.substring(dot)
    }
}
