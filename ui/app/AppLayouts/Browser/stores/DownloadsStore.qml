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

    // Session-only Download Pill strip. Never restored from Download History (ADR 0006 / issue 03).
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

    // Player pages for downloaded media (see mediaPlayerPageUrl); temp, disposable.
    property string mediaPlayerDirectory: {
        const loc = StandardPaths.writableLocation(StandardPaths.TempLocation)
        return loc ? String(loc).replace("file://", "").replace(/[/\\]+$/, "") + "/status-browser-player" : ""
    }

    // Text file writer; production uses StringUtils, tests inject a fake.
    property var writeTextFileFn: function(path, data) {
        return StringUtils.writeTextFile(path, data)
    }

    // Text file reader; reads qrc: and file: alike. Tests inject a fake.
    property var readTextFileFn: function(path) {
        return StringUtils.readTextFile(path)
    }

    // Player page assets, substituted and inlined by _mediaPlayerHtml.
    readonly property url mediaPlayerTemplateUrl:
        Qt.resolvedUrl("../webview/player/media_player.html")
    readonly property url mediaPlayerScriptUrl:
        Qt.resolvedUrl("../webview/player/media_player.js")

    property string _mediaPlayerTemplateCache: ""

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

    // Desktop Copy file path / Copy URL; production uses ClipboardUtils.
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
    /// Prefer `downloadsListModel` for bindings; this remains for one-shot lookups.
    function downloadsListNewestFirst() {
        return downloadsListModel
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

    /// Open-in-Browser allowlist: types our Backends render (ADR 0006 §8).
    /// Images, plain text, HTML; PDF when Backend supports it; media per
    /// isPlayableMedia. Everything else is handed to the OS.
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
        return isPlayableMedia(record)
    }

    /// Media our Backends can decode — and only inside a page (see mediaPlayerPageUrl).
    ///
    /// MP4/M4A/AAC are deliberately absent: the shipped Chromium is built without
    /// proprietary codecs, so H.264/AAC fail with DEMUXER_ERROR_NO_SUPPORTED_STREAMS
    /// and would leave the user staring at a dead player. They go to the OS instead,
    /// as do Ogg and Matroska. Revisit if the build ever gains those codecs.
    function isPlayableMedia(record) {
        if (!record)
            return false

        const mime = String(record.mimeType || "").toLowerCase()
        const name = String(record.fileName || "").toLowerCase()

        if (mime === "audio/mpeg" || mime === "audio/mp3" || name.endsWith(".mp3"))
            return true
        if (mime === "audio/wav" || mime === "audio/x-wav" || mime === "audio/wave"
                || name.endsWith(".wav"))
            return true
        if (mime === "video/webm" || mime === "audio/webm" || name.endsWith(".webm"))
            return true
        return false
    }

    /// The only file:// URLs the browser may navigate to: player pages we generated
    /// and the Download Targets of Records the user downloaded. Everything else stays
    /// blocked by the Backend's local-browsing guard (WebViewAdapter).
    function isBrowsableLocalUrl(url) {
        const path = UrlUtils.convertUrlToLocalPath(String(url || ""))
        if (!path)
            return false

        const dir = root.mediaPlayerDirectory
        if (dir && path.startsWith(dir + "/player-") && path.endsWith(".html"))
            return true

        for (let i = 0; i < root.downloadModel.length; ++i) {
            const record = root.downloadModel[i]
            if (record && String(record.targetPath || "") === path)
                return true
        }
        return false
    }

    /// Write (and reuse) a player page for a downloaded media Record and return its
    /// file URL, or "" when it cannot be written.
    ///
    /// A top-level navigation to local audio/video is turned into a fresh Download by
    /// WebEngine (net::ERR_ABORTED), which re-saves the file as "name (1)" instead of
    /// playing it. The same file inside a file:// page plays fine, so we hand the tab
    /// a one-element page instead of the media itself.
    function mediaPlayerPageUrl(record) {
        if (!isPlayableMedia(record) || record.missingFile)
            return ""
        const path = String(record.targetPath || "")
        if (!path)
            return ""

        const dir = root.mediaPlayerDirectory
        if (!dir)
            return ""
        if (root.ensureDirectoryFn)
            root.ensureDirectoryFn(dir)

        const html = _mediaPlayerHtml(record, path)
        if (!html)
            return ""

        // One page per target path: replaying a file reuses it instead of piling up.
        const pagePath = joinPath(dir, "player-" + _pathKey(path) + ".html")
        if (!root.writeTextFileFn(pagePath, html))
            return ""
        return UrlUtils.urlFromUserInput(pagePath)
    }

    /// media_player.html with its placeholders filled in, or "" when the asset is
    /// unreadable. Function replacements throughout: a file name may contain "$&".
    function _mediaPlayerHtml(record, path) {
        const template = _mediaPlayerTemplate()
        if (!template)
            return ""

        const tag = _isVideoRecord(record) ? "video" : "audio"
        const name = StringUtils.escapeHtml(String(record.fileName || ""))
        // Every path segment is percent-encoded, so the src carries no quote to escape.
        const src = _fileUrlForPage(path)
        const failed = StringUtils.escapeHtml(
                         qsTr("This file cannot be played here. Open it with another app."))

        return template
            .replace(/__TAG__/g, () => tag)
            .replace(/__SRC__/g, () => src)
            .replace(/__NAME__/g, () => name)
            .replace(/__FAILED__/g, () => failed)
    }

    /// media_player.html with media_player.js inlined, read once per session.
    /// One page beats a page plus a sibling script copied into the temp directory.
    function _mediaPlayerTemplate() {
        if (root._mediaPlayerTemplateCache)
            return root._mediaPlayerTemplateCache

        const html = String(root.readTextFileFn(root.mediaPlayerTemplateUrl) || "")
        if (!html)
            return ""
        const script = String(root.readTextFileFn(root.mediaPlayerScriptUrl) || "")
        root._mediaPlayerTemplateCache = html.replace(/__SCRIPT__/g, () => script)
        return root._mediaPlayerTemplateCache
    }

    function _isVideoRecord(record) {
        const mime = String(record.mimeType || "").toLowerCase()
        const name = String(record.fileName || "").toLowerCase()
        if (mime.startsWith("audio/"))
            return false
        return mime.startsWith("video/") || name.endsWith(".webm")
    }

    /// Absolute path → file URL safe to inline in HTML. Drive letters keep their colon
    /// so Windows targets stay valid ("C:/x" → "file:///C:/x").
    function _fileUrlForPage(path) {
        const encoded = String(path).replace(/\\/g, "/").split("/")
            .map(segment => /^[A-Za-z]:$/.test(segment) ? segment : encodeURIComponent(segment))
            .join("/")
        return encoded.startsWith("/") ? "file://" + encoded : "file:///" + encoded
    }

    function _pathKey(path) {
        let hash = 5381
        for (let i = 0; i < path.length; ++i)
            hash = ((hash << 5) + hash + path.charCodeAt(i)) >>> 0
        return hash.toString(16)
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

    /// Shared subtitle for Downloads List / Download Pill (one wording per state).
    function statusText(record) {
        if (!record)
            return ""
        if (record.missingFile)
            return qsTr("Missing file")
        const state = record.state
        if (state === AbstractWebView.DownloadState.DownloadCompleted)
            return ""
        if (state === AbstractWebView.DownloadState.DownloadCancelled)
            return qsTr("Canceled")
        if (state === AbstractWebView.DownloadState.DownloadInterrupted)
            return qsTr("Interrupted")
        // InProgress, Requested, and Paused: received/total. Resume control carries paused.
        if (state === AbstractWebView.DownloadState.DownloadInProgress
                || state === AbstractWebView.DownloadState.DownloadRequested
                || state === AbstractWebView.DownloadState.DownloadPaused
                || record.isPaused) {
            const received = record.receivedBytes ?? 0
            const total = record.totalBytes ?? 0
            if (total > 0) {
                return "%1 / %2"
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
