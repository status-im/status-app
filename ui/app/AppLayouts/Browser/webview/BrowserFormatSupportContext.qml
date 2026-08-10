import QtQuick

import StatusQ.Internal

import "DownloadFormatUtils.js" as DownloadFormatUtils

/**
 * What this build opens and plays, asked at runtime (ADR 0006 §8).
 *
 * Two answers meet here. The Backend Capabilities and the shared allowlist say
 * which formats the browser routes into a Tab; the engine probe asks the media
 * stack itself, through the page, whether it can decode them. A format is
 * listed as supported only when both agree — the probe can take a format away,
 * never add one, because a format the allowlist refuses goes to the OS however
 * well the engine decodes it.
 *
 * Backends whose runJavaScript carries no result (mobile) simply never answer;
 * the Capability answers stand and engineChecked stays false.
 */
QtObject {
    id: root

    // Backend Capabilities, not platform checks. Injectable for QML tests.
    property bool inPageMediaPlaybackSupported:
        BrowserBackendCapabilities.inPageMediaPlaybackSupported
    property bool proprietaryCodecsSupported:
        BrowserBackendCapabilities.proprietaryCodecsSupported

    // The Backend's PDF-rendering Capability; the owner binds it.
    property bool supportsPdf: false

    /// Runs a script in the current page. The callback only arrives on Backends
    /// that return a result.
    property var runJavaScriptFn: function(script, callback) {}

    /// True once the engine answered the probe.
    readonly property bool engineChecked: !!root._engineAnswers

    /// [{title, formats: [{name, detail, supported}]}] — one section per group,
    /// ready to render.
    readonly property var sections: [
        {
            title: qsTr("Audio and video"),
            formats: root._resolve("media")
        },
        {
            title: qsTr("Documents and images"),
            formats: root._resolve("document")
        }
    ]

    /// Asks the page's media stack what it can decode. Answers land in
    /// _engineAnswers and re-evaluate sections.
    function checkEngine() {
        const types = root._catalogue.filter(entry => !!entry.probeType)
                                     .map(entry => entry.probeType)
        if (!types.length || !root.runJavaScriptFn)
            return
        root.runJavaScriptFn(root._probeScript(types), function(result) {
            root._engineAnswers = root._parseAnswers(result)
        })
    }

    // mimeType alone drives the allowlist, so no sample file name is needed.
    // probeType is the type string handed to canPlayType — media only.
    readonly property var _catalogue: [
        { group: "media", name: "MP3", detail: ".mp3", mimeType: "audio/mpeg",
          probeType: "audio/mpeg" },
        { group: "media", name: "WAV", detail: ".wav", mimeType: "audio/wav",
          probeType: "audio/wav; codecs=\"1\"" },
        { group: "media", name: "WebM (VP8/VP9, Opus)", detail: ".webm",
          mimeType: "video/webm", probeType: "video/webm; codecs=\"vp9, opus\"" },
        { group: "media", name: "MP4 (H.264, AAC)", detail: ".mp4, .m4v",
          mimeType: "video/mp4", probeType: "video/mp4; codecs=\"avc1.42E01E, mp4a.40.2\"" },
        { group: "media", name: "AAC (M4A)", detail: ".m4a, .aac",
          mimeType: "audio/mp4", probeType: "audio/mp4; codecs=\"mp4a.40.2\"" },
        { group: "media", name: "Ogg (Vorbis)", detail: ".ogg, .oga",
          mimeType: "audio/ogg", probeType: "audio/ogg; codecs=\"vorbis\"" },
        { group: "media", name: "Matroska", detail: ".mkv",
          mimeType: "video/x-matroska", probeType: "video/x-matroska" },
        { group: "document", name: "PDF", detail: ".pdf", mimeType: "application/pdf",
          probeType: "" },
        { group: "document", name: qsTr("Images"),
          detail: ".png, .jpg, .gif, .webp, .bmp, .svg", mimeType: "image/png",
          probeType: "" },
        { group: "document", name: qsTr("Text and HTML"), detail: ".txt, .html, .xhtml",
          mimeType: "text/html", probeType: "" }
    ]

    // canPlayType answers keyed by probe type, or null while unasked.
    property var _engineAnswers: null

    function _resolve(group) {
        return root._catalogue.filter(entry => entry.group === group).map(entry => {
            return {
                name: entry.name,
                detail: entry.detail,
                supported: root._isSupported(entry)
            }
        })
    }

    function _isSupported(entry) {
        const allowed = DownloadFormatUtils.canOpenInBrowser(
                          entry.mimeType, "", root.supportsPdf,
                          root.inPageMediaPlaybackSupported,
                          root.proprietaryCodecsSupported)
        if (!allowed)
            return false
        const answers = root._engineAnswers
        if (!answers || !entry.probeType || answers[entry.probeType] === undefined)
            return true
        return !!answers[entry.probeType]
    }

    // canPlayType answers "", "maybe" or "probably"; MediaSource covers types a
    // bare media element declines to judge. The result comes back as JSON so
    // Backends that stringify their return value stay readable.
    function _probeScript(types) {
        return "(function() {"
             + "  var types = " + JSON.stringify(types) + ";"
             + "  var probe = document.createElement('video');"
             + "  var answers = {};"
             + "  for (var i = 0; i < types.length; ++i) {"
             + "    var answer = '';"
             + "    try { answer = probe.canPlayType(types[i]) || '' } catch (e) { answer = '' }"
             + "    if (!answer && window.MediaSource && MediaSource.isTypeSupported) {"
             + "      try { if (MediaSource.isTypeSupported(types[i])) answer = 'maybe' } catch (e) {}"
             + "    }"
             + "    answers[types[i]] = answer;"
             + "  }"
             + "  return JSON.stringify(answers);"
             + "})()"
    }

    function _parseAnswers(result) {
        if (!result)
            return null
        if (typeof result === "object")
            return result
        try {
            return JSON.parse(String(result))
        } catch (e) {
            return null
        }
    }
}
