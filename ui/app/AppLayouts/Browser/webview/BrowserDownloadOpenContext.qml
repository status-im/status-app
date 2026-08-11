import QtCore
import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Internal

import utils

import AppLayouts.Browser.adapters

import "DownloadFormatUtils.js" as DownloadFormatUtils

/**
 * The open-a-downloaded-file seam (ADR 0006 §8): one place that knows which
 * Download Records our Backends can render and how the player page for local
 * media is assembled. Which file:// URLs may be reached is not decided here —
 * the Backend owns that policy (see ProfileManager / browserprofileutils.cpp).
 *
 * Composed inside BrowserDownloadsContext. Dependencies are narrow injected
 * functions — never a store reference; supportsPdf (a Backend Capability) is
 * a plain per-call input.
 *
 * openInBrowser() makes the open-route choice: a generated player page for
 * media (only where the Backend needs one — otherwise the media file itself
 * via openFileUrlFn), a direct navigation for everything else. A false return
 * means "not renderable here" — the caller hands the file to the OS.
 */
QtObject {
    id: root

    /// Opens a URL in the browser; injected by the owner.
    property var openUrlFn: function(url) {
        console.warn("BrowserDownloadOpenContext: openUrlFn not set")
    }

    /// Opens a local file with a read grant for a directory (AbstractWebView
    /// loadFileUrl); empty readAccessUrl means the file's own directory.
    property var openFileUrlFn: function(fileUrl, readAccessUrl) {
        console.warn("BrowserDownloadOpenContext: openFileUrlFn not set")
    }

    // Text file writer; production uses StringUtils, tests inject a fake.
    property var writeTextFileFn: function(path, data) {
        return StringUtils.writeTextFile(path, data)
    }

    // Text file reader; reads qrc: and file: alike. Tests inject a fake.
    property var readTextFileFn: function(path) {
        return StringUtils.readTextFile(path)
    }

    // Directory create; injectable so Storybook/unit tests need not stub SystemUtils.
    property var ensureDirectoryFn: function(path) {
        return SystemUtils.ensureDirectory(path)
    }

    // Backend Capability, not a platform check. Injectable for QML tests.
    property bool inBrowserMediaPlaybackSupported:
        BrowserBackendCapabilities.inPageMediaPlaybackSupported

    // H.264/AAC ride on the Backend too — absent from our WebEngine build,
    // native to WebKit and the Android WebView. Injectable for QML tests.
    property bool proprietaryCodecsSupported:
        BrowserBackendCapabilities.proprietaryCodecsSupported

    // Does this Backend need the player page at all? Only the ones that turn a
    // navigation to local media into a download do. Injectable for QML tests.
    property bool mediaPlayerPageRequired:
        BrowserBackendCapabilities.mediaPlayerPageRequired

    // Player pages for downloaded media (see mediaPlayerPageUrl); temp, disposable.
    // The subdirectory name is also an allowed root of the Backend's local-browsing
    // policy — keep in sync with kMediaPlayerDirName in browserprofileutils.cpp.
    property string mediaPlayerDirectory: {
        const loc = StandardPaths.writableLocation(StandardPaths.TempLocation)
        return loc ? String(loc).replace("file://", "").replace(/[/\\]+$/, "") + "/status-browser-player" : ""
    }

    // Player page assets, substituted and inlined by d.mediaPlayerHtml.
    readonly property url mediaPlayerTemplateUrl:
        Qt.resolvedUrl("player/media_player.html")
    readonly property url mediaPlayerScriptUrl:
        Qt.resolvedUrl("player/media_player.js")

    readonly property QtObject d: QtObject {

        property string mediaPlayerTemplateCache: ""

        /// media_player.html with its placeholders filled in, or "" when the asset is
        /// unreadable. Function replacements throughout: a file name may contain "$&".
        function mediaPlayerHtml(record, path) {
            const template = d.mediaPlayerTemplate()
            if (!template)
                return ""

            const tag = DownloadFormatUtils.isVideoMedia(record.mimeType, record.fileName)
                        ? "video" : "audio"
            const name = StringUtils.escapeHtml(String(record.fileName || ""))
            // Every path segment is percent-encoded, so the src carries no quote to escape.
            const src = d.fileUrlForPage(path)
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
        function mediaPlayerTemplate() {
            if (d.mediaPlayerTemplateCache)
                return d.mediaPlayerTemplateCache

            const html = String(root.readTextFileFn(root.mediaPlayerTemplateUrl) || "")
            if (!html)
                return ""
            const script = String(root.readTextFileFn(root.mediaPlayerScriptUrl) || "")
            d.mediaPlayerTemplateCache = html.replace(/__SCRIPT__/g, () => script)
            return d.mediaPlayerTemplateCache
        }

        /// Absolute path → file URL safe to inline in HTML. Drive letters keep their colon
        /// so Windows targets stay valid ("C:/x" → "file:///C:/x").
        function fileUrlForPage(path) {
            const encoded = String(path).replace(/\\/g, "/").split("/")
                .map(segment => /^[A-Za-z]:$/.test(segment) ? segment : encodeURIComponent(segment))
                .join("/")
            return encoded.startsWith("/") ? "file://" + encoded : "file:///" + encoded
        }

        function pathKey(path) {
            let hash = 5381
            for (let i = 0; i < path.length; ++i)
                hash = ((hash << 5) + hash + path.charCodeAt(i)) >>> 0
            return hash.toString(16)
        }

        function joinPath(dir, fileName) {
            if (!dir)
                return fileName
            if (dir.endsWith("/") || dir.endsWith("\\"))
                return dir + fileName
            return dir + "/" + fileName
        }
    }

    /// Open-in-Browser gate for a Record: Completed, still on disk, and a type
    /// on the shared allowlist (DownloadFormatUtils / ADR 0006 §8). supportsPdf
    /// is the Backend Capability, evaluated by the caller at call time.
    function canOpenInBrowser(record, supportsPdf) {
        if (!record || record.missingFile)
            return false
        if (record.state !== AbstractWebView.DownloadState.DownloadCompleted)
            return false
        return DownloadFormatUtils.canOpenInBrowser(
                    record.mimeType, record.fileName, supportsPdf,
                    root.inBrowserMediaPlaybackSupported,
                    root.proprietaryCodecsSupported)
    }

    /// The in-browser open route, or false for the OS handoff.
    /// Media goes through a player page on Backends that need one: navigating
    /// to local audio/video makes WebEngine download it again instead of
    /// playing it. No page where one is needed, no in-browser route.
    function openInBrowser(record, supportsPdf) {
        if (!canOpenInBrowser(record, supportsPdf))
            return false
        const path = record.targetPath
        if (!path)
            return false

        if (DownloadFormatUtils.isPlayableMedia(record.mimeType, record.fileName,
                                               root.proprietaryCodecsSupported)) {
            // Backends that play a directly loaded file get the file itself,
            // read-granted to its own directory (empty = the narrowest grant).
            if (!root.mediaPlayerPageRequired) {
                root.openFileUrlFn(UrlUtils.urlFromUserInput(path), "")
                return true
            }
            const page = mediaPlayerPageUrl(record)
            if (!page)
                return false
            root.openUrlFn(page)
            return true
        }

        root.openUrlFn(UrlUtils.urlFromUserInput(path))
        return true
    }

    /// Write (and reuse) a player page for a downloaded media Record and return its
    /// file URL, or "" when it cannot be written.
    ///
    /// A top-level navigation to local audio/video is turned into a fresh Download by
    /// WebEngine (net::ERR_ABORTED), which re-saves the file as "name (1)" instead of
    /// playing it. The same file inside a file:// page plays fine, so we hand the tab
    /// a one-element page instead of the media itself.
    function mediaPlayerPageUrl(record) {
        if (!record || record.missingFile
                || !DownloadFormatUtils.isPlayableMedia(record.mimeType, record.fileName,
                                                        root.proprietaryCodecsSupported))
            return ""
        const path = String(record.targetPath || "")
        if (!path)
            return ""

        const dir = root.mediaPlayerDirectory
        if (!dir)
            return ""
        if (root.ensureDirectoryFn)
            root.ensureDirectoryFn(dir)

        const html = d.mediaPlayerHtml(record, path)
        if (!html)
            return ""

        // One page per target path: replaying a file reuses it instead of piling up.
        const pagePath = d.joinPath(dir, "player-" + d.pathKey(path) + ".html")
        if (!root.writeTextFileFn(pagePath, html))
            return ""
        return UrlUtils.urlFromUserInput(pagePath)
    }

}
