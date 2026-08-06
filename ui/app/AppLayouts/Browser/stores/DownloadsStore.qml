import QtCore
import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Internal

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

    // Session-only Download Pill strip. Never restored from Download History (ADR 0006).
    property var downloadStripModel: []

    /// Newest-first list for the Downloads overview. Recomputes when downloadModel
    /// changes so an open TabsBookmarksOverviewModal stays live (not a createObject snapshot).
    readonly property var downloadsListModel: {
        const src = downloadModel
        const list = []
        for (let i = src.length - 1; i >= 0; --i)
            list.push(src[i])
        return list
    }

    // Browser preferences (same mechanism as Tab Session). Optional in unit tests.
    property var preferencesStore: null

    property int historyCap: 200
    property int historySaveDebounceMs: 700

    // Host Download Target policy: platform downloads location (overridable in tests).
    property string downloadsDirectory: {
        const loc = StandardPaths.writableLocation(StandardPaths.DownloadLocation)
        return loc ? String(loc).replace("file://", "") : ""
    }

    /// The one platform seam: filesystem, share/clipboard, and the two platform
    /// facts the store branches on. Production injects nothing — the default
    /// wraps SystemUtils / ShareUtils / ClipboardUtils; tests inject one fake:
    /// - fileExists(path) → bool — disk existence probe (Missing File, collisions)
    /// - ensureDirectory(path) → bool — create the downloads directory
    /// - sharePaths([path]) — mobile share sheet for files
    /// - shareText(text) — mobile share sheet for text/URL
    /// - copyText(text) — desktop Copy file path / Copy URL
    /// - showInFolder(path) — desktop reveals file; Android opens system Downloads UI
    /// - preferShareSheet: bool — mobile → share sheet; desktop → copy
    /// - showInFolderSupported: bool — Desktop + Android; hidden on iOS
    ///   (ADR 0006)
    property var platform: ({
        fileExists: function(path) { return SystemUtils.fileExists(path) },
        ensureDirectory: function(path) { return SystemUtils.ensureDirectory(path) },
        sharePaths: function(paths) { SystemUtils.sharePaths(paths) },
        shareText: function(text) { ShareUtils.shareText(text) },
        copyText: function(text) { ClipboardUtils.setText(text) },
        showInFolder: function(path) { SystemUtils.showInFolder(path) },
        preferShareSheet: SQUtils.Utils.isMobile,
        showInFolderSupported: !SQUtils.Utils.isIOS
    })

    readonly property url _downloadRecordUrl: Qt.resolvedUrl("DownloadRecord.qml")

    /// Emitted when a host Web View no longer owns any non-terminal Downloads.
    /// BrowserWebViewContext destroys Retained Views on this signal (ADR 0006 §6).
    signal viewDownloadsCleared(var view)

    readonly property Timer _historySaveTimer: Timer {
        interval: Math.max(0, root.historySaveDebounceMs)
        repeat: false
        onTriggered: root.saveDownloadHistoryNow()
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
        // Newest pills first — strip shifts existing items right (animated in the view).
        downloadStripModel = [record].concat(downloadStripModel)
        root.enforceHistoryCap()
        root.scheduleSaveDownloadHistory()
        return record
    }

    /// Retry: re-bind a new live Backend Download onto an existing Interrupted/Cancelled
    /// Record so History / overview keep one identity (no duplicate Cancelled + InProgress).
    function reattachForRetry(record, download, hostView) {
        if (!record || !download)
            return null
        // Dropped by clear/evict, so already queued for destroy() — reattaching
        // would resurrect a dying QObject. The caller starts a fresh Record.
        if (downloadModel.indexOf(record) < 0)
            return null

        record.errorString = ""
        record.missingFile = false
        record.startTime = new Date()
        record.receivedBytes = 0
        record.isPaused = false
        record.state = AbstractWebView.DownloadState.DownloadRequested

        if (hostView)
            record.originatingView = hostView
        else if (download.view)
            record.originatingView = download.view

        if (hostView && hostView.offTheRecord !== undefined)
            record.offTheRecord = !!hostView.offTheRecord

        record.attach(download)

        // Newest in History (oldest-first array → append).
        const rest = []
        for (let i = 0; i < downloadModel.length; ++i) {
            if (downloadModel[i] !== record)
                rest.push(downloadModel[i])
        }
        downloadModel = rest.concat([record])

        // Front of the session strip.
        dismissRecordFromStrip(record)
        downloadStripModel = [record].concat(downloadStripModel)

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
    function dismissRecordFromStrip(record) {
        if (!record)
            return
        for (let i = 0; i < downloadStripModel.length; ++i) {
            if (downloadStripModel[i] === record) {
                const next = downloadStripModel.slice()
                next.splice(i, 1)
                downloadStripModel = next
                return
            }
        }
    }

    function clearDownloadStrip() {
        downloadStripModel = []
    }

    function openRecord(record) {
        if (!record || record.missingFile)
            return
        Qt.openUrlExternally(UrlUtils.urlFromUserInput(record.targetPath))
    }

    function openDirectoryForRecord(record) {
        if (!record || !canShowInFolder(record))
            return
        // Prefer the file path so desktop can reveal/select it; Android opens
        // the system Downloads UI and ignores the path.
        const path = record.targetPath || record.downloadDirectory
        if (!path)
            return
        if (root.platform && root.platform.showInFolder)
            root.platform.showInFolder(path)
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
            record.missingFile = !(path && root.platform && root.platform.fileExists
                                   && root.platform.fileExists(path))
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
        if (!root.platform || !root.platform.showInFolderSupported || !record || record.missingFile)
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

    /// Mobile: system share sheet. Desktop: copy the Download Target path.
    function shareFile(record) {
        if (!canShareFile(record))
            return false
        const path = record.targetPath
        if (root.platform.preferShareSheet) {
            if (root.platform.sharePaths)
                root.platform.sharePaths([path])
        } else if (root.platform.copyText) {
            root.platform.copyText(path)
        }
        return true
    }

    /// Mobile: system share sheet. Desktop: copy the source URL.
    function shareUrl(record) {
        return shareUrlString(sourceUrlString(record))
    }

    /// Same share-vs-copy policy for a raw URL (link long-press menu).
    function shareUrlString(url) {
        const text = String(url || "")
        if (!text)
            return false
        if (root.platform.preferShareSheet) {
            if (root.platform.shareText)
                root.platform.shareText(text)
        } else if (root.platform.copyText) {
            root.platform.copyText(text)
        }
        return true
    }

    // Formatting (elideFileName) lives in
    // webview/DownloadFormatUtils.js — pure functions, imported by the pill.

    /// Sanitize a suggested file name and resolve a free Download Target under downloadsDirectory.
    /// Collisions with existing files or in-session Records get "(1)", "(2)", … suffixes.
    function _resolveDownloadTarget(suggestedFileName) {
        const dir = root.downloadsDirectory.replace(/[/\\]+$/, "")
        if (root.platform && root.platform.ensureDirectory)
            root.platform.ensureDirectory(dir)

        let name = String(suggestedFileName || "").trim()
        if (!name)
            name = "download.bin"
        name = name.replace(/[\\/]/g, "_")

        let candidate = _joinPath(dir, name)
        let n = 1
        while (_pathTaken(candidate)) {
            candidate = _joinPath(dir, _withCollisionSuffix(name, n))
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
        const target = _resolveDownloadTarget(suggested)
        const parts = _splitPath(target)

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

        // Restore replaces the list; dropped Records die unless still running.
        const kept = []
        for (let i = 0; i < downloadModel.length; ++i) {
            const previous = downloadModel[i]
            if (previous && !root._destroyRecord(previous))
                kept.push(previous)
        }
        downloadModel = restored.concat(kept)
        enforceHistoryCap()
    }

    /// Destroy a Record: as createObject(root) children they outlive removal
    /// from downloadModel. Returns false for one still driving a Download.
    function _destroyRecord(record) {
        if (!record || !record.isTerminal)
            return false
        dismissRecordFromStrip(record)
        record.detach()
        record.destroy()
        return true
    }

    /// Clear Download History Records only — files on disk are left alone (ADR 0006).
    function clearDownloadHistory() {
        // Non-terminal Records stay — they still drive a Retained View (§6).
        const kept = []
        for (let i = 0; i < downloadModel.length; ++i) {
            const record = downloadModel[i]
            if (record && !root._destroyRecord(record))
                kept.push(record)
        }
        downloadModel = kept
        downloadStripModel = []
        if (preferencesStore && preferencesStore.clearDownloadHistoryRaw)
            preferencesStore.clearDownloadHistoryRaw()
        else if (preferencesStore && preferencesStore.setDownloadHistoryRaw)
            preferencesStore.setDownloadHistoryRaw("[]")
    }

    function enforceHistoryCap() {
        // Only terminal Records are evictable — a running Download keeps its Record.
        let persistableIndexes = []
        for (let i = 0; i < downloadModel.length; ++i) {
            const record = downloadModel[i]
            if (record && !record.offTheRecord && record.isTerminal)
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
            if (drop[i])
                root._destroyRecord(downloadModel[i])
            else
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

    function _pathTaken(path) {
        if (root.platform && root.platform.fileExists && root.platform.fileExists(path))
            return true
        for (let i = 0; i < downloadModel.length; ++i) {
            const record = downloadModel[i]
            if (record && record.targetPath === path)
                return true
        }
        return false
    }

    function _joinPath(dir, fileName) {
        if (!dir)
            return fileName
        if (dir.endsWith("/") || dir.endsWith("\\"))
            return dir + fileName
        return dir + "/" + fileName
    }

    function _splitPath(path) {
        const s = String(path)
        const slash = Math.max(s.lastIndexOf("/"), s.lastIndexOf("\\"))
        if (slash < 0)
            return { dir: "", fileName: s }
        return { dir: s.substring(0, slash), fileName: s.substring(slash + 1) }
    }

    function _withCollisionSuffix(fileName, n) {
        const dot = fileName.lastIndexOf(".")
        if (dot <= 0)
            return fileName + " (" + n + ")"
        return fileName.substring(0, dot) + " (" + n + ")" + fileName.substring(dot)
    }
}
