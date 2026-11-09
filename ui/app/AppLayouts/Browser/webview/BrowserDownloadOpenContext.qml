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
 * media where the Backend needs one, otherwise the file itself, read-granted
 * to itself alone, both through openPreviewFn. A false return means "not
 * renderable here" — the caller hands the file to the OS.
 */
QtObject {
    id: root

    /// Opens a Preview Tab for a plan {url, readAccessUrl, openedFilePath, title};
    /// injected by the owner. The file loads through a Read Grant for
    /// readAccessUrl, or, when that is "", as a page (the player page).
    /// openedFilePath names the Opened File the Tab shows, "" for a Download;
    /// title holds until the page gives one.
    property var openPreviewFn: function(plan) {
        console.warn("BrowserDownloadOpenContext: openPreviewFn not set")
    }

    // Text file writer; production uses StringUtils, tests inject a fake.
    property var writeTextFileFn: function(path, data) {
        return StringUtils.writeTextFile(path, data)
    }

    // Text file reader; reads qrc: and file: alike. Tests inject a fake.
    property var readTextFileFn: function(path) {
        return StringUtils.readTextFile(path)
    }

    // Existence probe for an Opened File; tests inject a fake.
    property var fileExistsFn: function(path) {
        return SystemUtils.fileExists(path)
    }

    // {name, mimeType, readable} the platform gave for an Opened File whose URL
    // names no file to probe (Android content://), {} otherwise. Tests inject a fake.
    property var openedFileInfoFn: function(fileUrl) {
        return SystemUtils.openedFileInfo(fileUrl)
    }

    // Local path of a file URL; tests inject a fake. On Android it copies a
    // content:// file out, so a described file never reaches it.
    property var localPathFn: function(fileUrl) {
        return UrlUtils.convertUrlToLocalPath(fileUrl)
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
        return loc ? UrlUtils.convertUrlToLocalPath(loc) + "/status-browser-player" : ""
    }

    // Player page assets, substituted and inlined by d.mediaPlayerHtml.
    readonly property url mediaPlayerTemplateUrl:
        Qt.resolvedUrl("player/media_player.html")
    readonly property url mediaPlayerScriptUrl:
        Qt.resolvedUrl("player/media_player.js")

    readonly property QtObject d: QtObject {

        /// The player page where the Backend needs one, otherwise the file
        /// itself, read-granted to itself alone; null when no page can be made.
        function plan(record, fileUrl, openedFilePath) {
            const title = openedFilePath ? record.fileName : ""
            if (root.mediaPlayerPageRequired
                    && DownloadFormatUtils.isPlayableMedia(record.mimeType, record.fileName,
                                                           root.proprietaryCodecsSupported)) {
                const page = root.mediaPlayerPageUrl(record)
                if (!page)
                    return null
                return { url: page, readAccessUrl: "", openedFilePath: openedFilePath, title: title }
            }
            return { url: fileUrl, readAccessUrl: fileUrl, openedFilePath: openedFilePath, title: title }
        }

        function open(plan) {
            if (!plan)
                return false
            root.openPreviewFn(plan)
            return true
        }

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
        return d.open(d.plan(record, UrlUtils.urlFromUserInput(path), ""))
    }

    /// An Opened File through the same allowlist and player page as a Record,
    /// read-granted to the file alone. False when it cannot be shown here.
    function openOpenedFile(fileUrl, supportsPdf) {
        return d.open(openedFilePlan(fileUrl, supportsPdf))
    }

    /// How an Opened File opens, or null when it cannot be shown here.
    /// A described file is taken at the platform's word and tagged by its URL.
    function openedFilePlan(fileUrl, supportsPdf) {
        const described = root.openedFileInfoFn(fileUrl) || {}
        const isDescribed = described.name !== undefined
        const path = isDescribed ? "" : root.localPathFn(fileUrl)
        if (isDescribed) {
            if (!described.readable)
                return null
        } else if (!path || !root.fileExistsFn(path)) {
            return null
        }
        const record = {
            targetPath: path,
            fileName: described.name ?? DownloadFormatUtils.fileNameOf(path),
            mimeType: described.mimeType ?? "",
            missingFile: false,
            state: AbstractWebView.DownloadState.DownloadCompleted
        }
        if (!canOpenInBrowser(record, supportsPdf))
            return null
        // A content:// URL renders by its provider's type, so the type must pass on its own.
        if (isDescribed && !DownloadFormatUtils.canOpenInBrowser(
                    record.mimeType, "", supportsPdf, root.inBrowserMediaPlaybackSupported,
                    root.proprietaryCodecsSupported))
            return null
        return d.plan(record, fileUrl, path || fileUrl)
    }

    /// The tag of an Opened File's Tab: its local path, or its URL when the
    /// platform described it.
    function openedFileTag(fileUrl) {
        if (!fileUrl)
            return ""
        const described = root.openedFileInfoFn(fileUrl) || {}
        if (described.name !== undefined)
            return fileUrl
        return root.localPathFn(fileUrl) || fileUrl
    }

    /// The name to show for an Opened File, from its Tab tag (a local path, or
    /// the URL of a described file).
    function openedFileName(openedFile) {
        const described = openedFile ? (root.openedFileInfoFn(openedFile) || {}) : {}
        return described.name ?? DownloadFormatUtils.fileNameOf(openedFile)
    }

    /// The name a Tab shows in place of its URL while it is still on its
    /// Opened File; "" once it has gone on to another page, or for other Tabs.
    function openedFileAddressLabel(view) {
        if (!view || !view.openedFilePath || view.canGoBack)
            return ""
        return openedFileName(view.openedFilePath)
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
