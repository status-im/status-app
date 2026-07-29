import QtCore
import QtQuick

import StatusQ
import StatusQ.Core

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

    readonly property url _downloadRecordUrl: Qt.resolvedUrl("DownloadRecord.qml")

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

    function addDownload(download) {
        const component = Qt.createComponent(_downloadRecordUrl)
        if (component.status !== Component.Ready) {
            console.error("DownloadsStore: failed to load DownloadRecord:", component.errorString())
            return null
        }
        const record = component.createObject(root)
        record.attach(download)
        if (download) {
            if (download.offTheRecord !== undefined)
                record.offTheRecord = !!download.offTheRecord
            else if (download.view && download.view.offTheRecord !== undefined)
                record.offTheRecord = !!download.view.offTheRecord
        }
        record.terminalReached.connect(function() {
            root.scheduleSaveDownloadHistory()
        })
        downloadModel = downloadModel.concat([record])
        root.enforceHistoryCap()
        root.scheduleSaveDownloadHistory()
        return record
    }

    function openFile(index) {
        const record = getDownload(index)
        if (!record)
            return
        Qt.openUrlExternally(UrlUtils.urlFromUserInput(record.targetPath))
    }

    function openDirectory(index) {
        const record = getDownload(index)
        if (!record)
            return
        Qt.openUrlExternally(UrlUtils.urlFromUserInput(record.downloadDirectory))
    }

    /// Sanitize a suggested file name and resolve a free Download Target under downloadsDirectory.
    /// Collisions with existing files or in-session Records get "(1)", "(2)", … suffixes.
    function resolveDownloadTarget(suggestedFileName) {
        const dir = root.downloadsDirectory.replace(/[/\\]+$/, "")
        SystemUtils.ensureDirectory(dir)

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
