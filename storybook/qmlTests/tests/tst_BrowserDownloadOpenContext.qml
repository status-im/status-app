import QtQuick
import QtTest

import StatusQ.Internal

import AppLayouts.Browser.adapters

/**
 * The open-a-downloaded-file seam (ADR 0006 §8): render/media allowlist and
 * player-page assembly.
 * Loads the real context; dependencies are the same narrow injected functions
 * production wires in.
 */
Item {
    id: root

    readonly property url openContextUrl: Qt.resolvedUrl(
        "../../../ui/app/AppLayouts/Browser/webview/BrowserDownloadOpenContext.qml")

    TestCase {
        name: "BrowserDownloadOpenContext"
        when: windowShown

        property var openedUrls: []
        property var openedFileUrls: []

        function createContext() {
            openedUrls = []
            openedFileUrls = []
            const component = Qt.createComponent(root.openContextUrl)
            verify(component.status === Component.Ready, component.errorString())
            const ctx = createTemporaryObject(component, root)
            ctx.mediaPlayerDirectory = "/tmp/status-player"
            ctx.ensureDirectoryFn = function(path) { return true }
            ctx.writeTextFileFn = function(path, data) { return true }
            ctx.openUrlFn = (url) => openedUrls.push(String(url))
            ctx.openFileUrlFn = (fileUrl, readAccessUrl) => openedFileUrls.push(
                { url: String(fileUrl), readAccess: String(readAccessUrl || "") })
            // The player page is what the desktop Backend needs; tests that
            // exercise the direct route flip this Capability themselves.
            ctx.mediaPlayerPageRequired = true
            return ctx
        }

        /// A Completed Download Record shape (target under /tmp/downloads).
        function completed(mime, name) {
            return {
                mimeType: mime,
                fileName: name,
                state: AbstractWebView.DownloadState.DownloadCompleted,
                missingFile: false,
                targetPath: "/tmp/downloads/" + name
            }
        }

        function test_canOpenInBrowser_allowlist_andPdfGate() {
            const ctx = createContext()

            const pngRec = completed("image/png", "a.png")
            const pdfRec = completed("application/pdf", "a.pdf")
            const binRec = completed("application/octet-stream", "a.bin")

            verify(ctx.canOpenInBrowser(pngRec, false))
            verify(!ctx.canOpenInBrowser(pdfRec, false))
            verify(ctx.canOpenInBrowser(pdfRec, true))
            verify(!ctx.canOpenInBrowser(binRec, true))
            pngRec.missingFile = true
            verify(!ctx.canOpenInBrowser(pngRec, false))
        }

        function test_canOpenInBrowser_requiresCompleted() {
            const ctx = createContext()
            const rec = completed("image/png", "a.png")
            rec.state = AbstractWebView.DownloadState.DownloadInProgress
            verify(!ctx.canOpenInBrowser(rec, false))
            verify(!ctx.canOpenInBrowser(null, false))
        }

        function test_canOpenInBrowser_mediaAllowlist_andExclusions() {
            const ctx = createContext()

            verify(ctx.canOpenInBrowser(completed("audio/mpeg", "a.mp3"), false))
            verify(ctx.canOpenInBrowser(completed("audio/wav", "a.wav"), false))
            verify(ctx.canOpenInBrowser(completed("video/webm", "a.webm"), false))

            // Ogg and Matroska are out on every Backend (platform media stack).
            verify(!ctx.canOpenInBrowser(completed("audio/ogg", "a.ogg"), true))
            verify(!ctx.canOpenInBrowser(completed("video/x-matroska", "a.mkv"), true))

            // H.264/AAC follow the Backend: absent from our WebEngine build, so a
            // player would load and fail to decode; native to WebKit and Android.
            ctx.proprietaryCodecsSupported = false
            verify(!ctx.canOpenInBrowser(completed("audio/mp4", "a.m4a"), true))
            verify(!ctx.canOpenInBrowser(completed("audio/aac", "a.aac"), true))
            verify(!ctx.canOpenInBrowser(completed("video/mp4", "a.mp4"), true))

            ctx.proprietaryCodecsSupported = true
            verify(ctx.canOpenInBrowser(completed("audio/mp4", "a.m4a"), true))
            verify(ctx.canOpenInBrowser(completed("audio/aac", "a.aac"), true))
            verify(ctx.canOpenInBrowser(completed("video/mp4", "a.mp4"), true))
            // Still out: the codec Capability does not widen the container list.
            verify(!ctx.canOpenInBrowser(completed("audio/ogg", "a.ogg"), true))
            verify(!ctx.canOpenInBrowser(completed("video/x-matroska", "a.mkv"), true))
            ctx.proprietaryCodecsSupported = false

            // Media playback is a Backend Capability, never a platform check.
            compare(ctx.inBrowserMediaPlaybackSupported,
                    BrowserBackendCapabilities.inPageMediaPlaybackSupported)
            compare(createContext().proprietaryCodecsSupported,
                    BrowserBackendCapabilities.proprietaryCodecsSupported)

            // Backend without in-page playback: media leaves the in-browser
            // route; images still render.
            ctx.inBrowserMediaPlaybackSupported = false
            verify(!ctx.canOpenInBrowser(completed("audio/mpeg", "b.mp3"), false))
            verify(!ctx.canOpenInBrowser(completed("video/webm", "b.webm"), false))
            verify(ctx.canOpenInBrowser(completed("image/png", "b.png"), false))
        }

        function test_mediaPlayerPage_writesPlayerForMedia_reusesPerTarget() {
            const ctx = createContext()

            let written = null
            ctx.writeTextFileFn = function(path, data) {
                written = { path: path, data: data }
                return true
            }

            const rec = completed("video/webm", "sample 30s (2).webm")

            const url = String(ctx.mediaPlayerPageUrl(rec))
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
            compare(String(ctx.mediaPlayerPageUrl(rec)), url)
            verify(!!written)
            compare(written.path, "/tmp/status-player/player-" + url.split("player-")[1].replace(".html", "") + ".html")
        }

        function test_mediaPlayerPage_audioTag_andEmptyWhenUnusable() {
            const ctx = createContext()

            let data = ""
            ctx.writeTextFileFn = function(path, text) { data = text; return true }

            const mp3 = completed("audio/mpeg", "tune.mp3")
            verify(String(ctx.mediaPlayerPageUrl(mp3)).length > 0)
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
            compare(String(ctx.mediaPlayerPageUrl(completed("application/pdf", "a.pdf"))), "")

            // A failed write leaves the caller to fall back to the OS handler.
            ctx.writeTextFileFn = function() { return false }
            compare(String(ctx.mediaPlayerPageUrl(completed("video/webm", "clip.webm"))), "")

            // Missing file blocks both routes.
            ctx.writeTextFileFn = function(path, text) { return true }
            const gone = completed("video/webm", "gone.webm")
            gone.missingFile = true
            compare(String(ctx.mediaPlayerPageUrl(gone)), "")

            // An unreadable page asset must not write a half-built page.
            let written = false
            ctx.writeTextFileFn = function(path, text) { written = true; return true }
            ctx._mediaPlayerTemplateCache = ""
            ctx.readTextFileFn = function(path) { return "" }
            compare(String(ctx.mediaPlayerPageUrl(completed("audio/mpeg", "b.mp3"))), "")
            verify(!written)
        }

        function test_openInBrowser_routeChoice_playerNavigateOrOsHandoff() {
            const ctx = createContext()

            // Media route: a generated player page, never the file itself.
            verify(ctx.openInBrowser(completed("video/webm", "clip.webm"), false))
            compare(openedUrls.length, 1)
            verify(openedUrls[0].startsWith("file:///tmp/status-player/player-"))
            verify(openedUrls[0].endsWith(".html"))

            // Static route: direct navigation to the Download Target.
            verify(ctx.openInBrowser(completed("image/png", "photo.png"), false))
            compare(openedUrls.length, 2)
            verify(openedUrls[1].indexOf("photo.png") >= 0)

            // Not renderable here → false: the caller hands off to the OS.
            verify(!ctx.openInBrowser(completed("application/octet-stream", "a.bin"), true))
            compare(openedUrls.length, 2)

            // No player page (write failed) → false, same OS handoff.
            ctx.writeTextFileFn = function() { return false }
            verify(!ctx.openInBrowser(completed("video/webm", "b.webm"), false))
            compare(openedUrls.length, 2)
        }

        /// The player page is a Backend workaround, so the route follows the
        /// Capability: no page needed → load the media file itself.
        function test_openInBrowser_mediaRoute_followsPlayerPageCapability() {
            const ctx = createContext()

            let written = 0
            ctx.writeTextFileFn = function() { written += 1; return true }
            ctx.mediaPlayerPageRequired = false

            verify(ctx.openInBrowser(completed("audio/mpeg", "tune.mp3"), false))
            compare(written, 0, "no page is generated where the Backend needs none")
            compare(openedUrls.length, 0)
            compare(openedFileUrls.length, 1)
            verify(openedFileUrls[0].url.startsWith("file://"))
            verify(openedFileUrls[0].url.endsWith("/tmp/downloads/tune.mp3"))
            // Empty read access = the file's own directory, the narrowest grant.
            compare(openedFileUrls[0].readAccess, "")

            // Non-media is unaffected: still a plain navigation.
            verify(ctx.openInBrowser(completed("image/png", "photo.png"), false))
            compare(openedFileUrls.length, 1)
            compare(openedUrls.length, 1)
            verify(openedUrls[0].indexOf("photo.png") >= 0)

            // Flipping the Capability back restores the player-page route —
            // the fallback stays one property away.
            ctx.mediaPlayerPageRequired = true
            verify(ctx.openInBrowser(completed("audio/mpeg", "tune.mp3"), false))
            compare(openedFileUrls.length, 1)
            compare(openedUrls.length, 2)
            verify(openedUrls[1].startsWith("file:///tmp/status-player/player-"))
            compare(written, 1)
        }

        /// The Capability is a Backend fact, not a platform check.
        function test_mediaPlayerPageRequired_defaultsToTheBackendCapability() {
            const component = Qt.createComponent(root.openContextUrl)
            verify(component.status === Component.Ready, component.errorString())
            const ctx = createTemporaryObject(component, root)
            compare(ctx.mediaPlayerPageRequired,
                    BrowserBackendCapabilities.mediaPlayerPageRequired)
        }
    }
}
