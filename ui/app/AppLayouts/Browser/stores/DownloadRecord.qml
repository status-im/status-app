import QtQuick

import AppLayouts.Browser.adapters

/**
 * Host-owned Download Record (see Browser CONTEXT / ADR 0006).
 * A live Backend Download may attach for progress; the Record survives after it is gone.
 */
QtObject {
    id: root

    property url url
    property string fileName: ""
    property string downloadDirectory: ""
    property string mimeType: ""
    property bool isInline: false
    property var startTime: new Date()
    property string errorString: ""
    // Incognito Downloads stay session-visible but never enter Download History.
    property bool offTheRecord: false
    // Lazily probed when the Downloads List is shown (or app returns to foreground).
    property bool missingFile: false

    property int state: AbstractWebView.DownloadState.DownloadRequested
    // double, not int: files over 2 GiB overflow a 32-bit QML int.
    property double receivedBytes: 0
    property double totalBytes: -1
    property bool isPaused: false

    // Transient Backend download (WebEngineDownloadRequest / MobileWebViewDownload). May become null.
    property var liveDownload: null

    // Host Web View that started this Download (LazyWebViewAdapter). Used for
    // Retained View ownership (ADR 0006 §6); never persisted.
    property var originatingView: null

    signal terminalReached()

    readonly property string targetPath: {
        if (!root.downloadDirectory)
            return root.fileName
        if (root.downloadDirectory.endsWith("/") || root.downloadDirectory.endsWith("\\"))
            return root.downloadDirectory + root.fileName
        return root.downloadDirectory + "/" + root.fileName
    }

    readonly property bool isTerminal: root.isTerminalState(root.state)

    /// Prefer this over `isTerminal` inside onStateChanged — the binding can lag.
    function isTerminalState(state) {
        return state === AbstractWebView.DownloadState.DownloadCompleted
            || state === AbstractWebView.DownloadState.DownloadCancelled
            || state === AbstractWebView.DownloadState.DownloadInterrupted
    }

    onStateChanged: {
        if (root.isTerminalState(root.state))
            root.terminalReached()
    }

    readonly property Connections _liveBindings: Connections {
        target: root.liveDownload
        enabled: !!root.liveDownload
        // WebEngine vs mobile Backend expose different path properties.
        ignoreUnknownSignals: true

        function onStateChanged() { root.syncFromLive() }
        function onReceivedBytesChanged() { root.syncFromLive() }
        function onTotalBytesChanged() { root.syncFromLive() }
        function onIsPausedChanged() { root.syncFromLive() }
        function onDownloadDirectoryChanged() { root.syncFromLive() }
        function onDownloadFileNameChanged() { root.syncFromLive() }
        function onDestinationPathChanged() { root.syncFromLive() }
    }

    onLiveDownloadChanged: {
        if (!root.liveDownload)
            return
        root.syncFromLive()
    }

    function attach(download) {
        if (!download)
            return
        root.liveDownload = download
        root.syncFromLive()
    }

    function detach() {
        root.liveDownload = null
    }

    function syncFromLive() {
        const d = root.liveDownload
        if (!d)
            return

        if (d.url !== undefined && d.url.toString() !== "")
            root.url = d.url

        // The accepted target wins: mobile leaves suggestedFileName unsuffixed.
        if (d.downloadFileName)
            root.fileName = d.downloadFileName
        else if (!root.fileName && d.suggestedFileName)
            root.fileName = d.suggestedFileName

        if (d.downloadDirectory)
            root.downloadDirectory = d.downloadDirectory
        else if (d.destinationPath) {
            const path = String(d.destinationPath)
            const slash = Math.max(path.lastIndexOf("/"), path.lastIndexOf("\\"))
            if (slash >= 0) {
                root.downloadDirectory = path.substring(0, slash)
                root.fileName = path.substring(slash + 1)
            }
        }

        if (d.mimeType !== undefined && d.mimeType !== "")
            root.mimeType = d.mimeType
        if (d.isInline !== undefined)
            root.isInline = !!d.isInline
        if (d.errorString !== undefined)
            root.errorString = d.errorString || ""

        if (d.receivedBytes !== undefined)
            root.receivedBytes = d.receivedBytes
        if (d.totalBytes !== undefined)
            root.totalBytes = d.totalBytes

        // Terminal Backend state always wins. WebEngine can leave isPaused true
        // after cancel(); preferring pause would stick the Record on Resume forever.
        if (d.state !== undefined && root.isTerminalState(d.state)) {
            root.state = d.state
            root.isPaused = false
            return
        }

        // Normalize to AbstractWebView seam: WebEngine keeps InProgress while paused;
        // expose DownloadPaused = 5 when isPaused is set.
        if (d.isPaused)
            root.state = AbstractWebView.DownloadState.DownloadPaused
        else if (d.state !== undefined)
            root.state = d.state

        root.isPaused = root.state === AbstractWebView.DownloadState.DownloadPaused
            || !!(d.isPaused)
    }

    function pause() {
        if (root.liveDownload && root.liveDownload.pause)
            root.liveDownload.pause()
    }

    function resume() {
        if (root.liveDownload && root.liveDownload.resume)
            root.liveDownload.resume()
    }

    function cancel() {
        if (root.liveDownload && root.liveDownload.cancel) {
            root.liveDownload.cancel()
            root.syncFromLive()
            // If the Backend has not flipped state yet (or left isPaused set),
            // force Cancelled so UI cannot stay on Resume + 0 bytes.
            if (!root.isTerminalState(root.state)) {
                root.isPaused = false
                root.state = AbstractWebView.DownloadState.DownloadCancelled
            }
            return
        }
        // Live object already gone: keep the Record actionable for the session.
        if (!root.isTerminal) {
            root.isPaused = false
            root.state = AbstractWebView.DownloadState.DownloadCancelled
        }
    }
}
