import QtQuick
import QtTest

/**
 * The Supported formats report (ADR 0006 §8): Backend Capabilities and the
 * shared allowlist answer first, the engine probe may take a format away.
 * Loads the real context; the Capabilities and the JS runner are injected the
 * way BrowserLayout wires them.
 */
Item {
    id: root

    readonly property url formatContextUrl: Qt.resolvedUrl(
        "../../../ui/app/AppLayouts/Browser/webview/BrowserFormatSupportContext.qml")

    TestCase {
        name: "BrowserFormatSupportContext"
        when: windowShown

        property var lastScript: ""

        function createContext(answers) {
            lastScript = ""
            const component = Qt.createComponent(root.formatContextUrl)
            verify(component.status === Component.Ready, component.errorString())
            const ctx = createTemporaryObject(component, root)
            ctx.inPageMediaPlaybackSupported = true
            ctx.proprietaryCodecsSupported = false
            ctx.supportsPdf = true
            // A Backend that answers; mobile-shaped runners drop the callback.
            ctx.runJavaScriptFn = function(script, callback) {
                lastScript = script
                if (answers !== undefined && callback)
                    callback(JSON.stringify(answers))
            }
            return ctx
        }

        function formatNamed(ctx, name) {
            const sections = ctx.sections
            for (let i = 0; i < sections.length; ++i) {
                const formats = sections[i].formats
                for (let j = 0; j < formats.length; ++j) {
                    if (formats[j].name === name)
                        return formats[j]
                }
            }
            return null
        }

        function test_capabilitiesAnswerBeforeAnyProbe() {
            const ctx = createContext()

            verify(!ctx.engineChecked)
            verify(formatNamed(ctx, "MP3").supported)
            verify(formatNamed(ctx, "WebM (VP8/VP9, Opus)").supported)
            verify(!formatNamed(ctx, "MP4 (H.264, AAC)").supported)
            verify(!formatNamed(ctx, "Ogg (Vorbis)").supported)
            verify(!formatNamed(ctx, "Matroska").supported)
            verify(formatNamed(ctx, "PDF").supported)
        }

        function test_proprietaryCodecsCapabilityOpensMp4AndAac() {
            const ctx = createContext()

            ctx.proprietaryCodecsSupported = true
            verify(formatNamed(ctx, "MP4 (H.264, AAC)").supported)
            verify(formatNamed(ctx, "AAC (M4A)").supported)
        }

        function test_noInPageMediaPlaybackLeavesDocumentsOnly() {
            const ctx = createContext()

            ctx.inPageMediaPlaybackSupported = false
            verify(!formatNamed(ctx, "MP3").supported)
            verify(formatNamed(ctx, "PDF").supported)
        }

        function test_pdfFollowsTheWebViewCapability() {
            const ctx = createContext()

            ctx.supportsPdf = false
            verify(!formatNamed(ctx, "PDF").supported)
            verify(formatNamed(ctx, "Images").supported)
        }

        function test_engineProbeTakesAwayWhatItCannotDecode() {
            const ctx = createContext({
                "audio/mpeg": "probably",
                "video/webm; codecs=\"vp9, opus\"": ""
            })

            ctx.checkEngine()
            verify(lastScript.indexOf("canPlayType") >= 0)
            verify(ctx.engineChecked)
            verify(formatNamed(ctx, "MP3").supported)
            verify(!formatNamed(ctx, "WebM (VP8/VP9, Opus)").supported)
            // An engine answer never opens what the allowlist refuses.
            verify(!formatNamed(ctx, "Ogg (Vorbis)").supported)
        }

        function test_probeWithoutAnswerLeavesTheCapabilityAnswers() {
            const ctx = createContext()

            ctx.checkEngine()
            verify(lastScript.length > 0)
            verify(!ctx.engineChecked)
            verify(formatNamed(ctx, "MP3").supported)
        }
    }
}
