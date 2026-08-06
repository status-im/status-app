.pragma library

// Pure format predicates for Download Records (ADR 0006 §8).
//
// Every input is a plain value — (mimeType, fileName, supportsPdf, …) — with
// no QML object access, so BrowserDownloadOpenContext and QML components can
// share one allowlist. supportsPdf is the Backend's PDF-rendering Capability;
// mediaPlaybackSupported is the platform's in-page playback gate. Both are
// passed in, never probed here.

/// Open-in-Browser allowlist: types our Backends render (ADR 0006 §8).
/// Images, plain text, HTML; PDF when the Backend supports it; media per
/// isPlayableMedia, gated by mediaPlaybackSupported (false on iOS: WebKit
/// rejects file:// media inside a file:// player page). Everything else is
/// handed to the OS.
///
/// Order matters and is behavior: a name ending in ".pdf" resolves on the
/// PDF branch even if its MIME type would also match media.
function canOpenInBrowser(mimeType, fileName, supportsPdf, mediaPlaybackSupported = true) {
    const mime = String(mimeType || "").toLowerCase()
    const name = String(fileName || "").toLowerCase()

    if (mime.startsWith("image/") || /\.(png|jpe?g|gif|webp|bmp|svg)$/.test(name))
        return true
    if (mime === "text/plain" || mime === "text/html" || mime === "application/xhtml+xml"
            || /\.(txt|html?|xhtml)$/.test(name))
        return true
    if (mime === "application/pdf" || name.endsWith(".pdf"))
        return !!supportsPdf
    return !!mediaPlaybackSupported && isPlayableMedia(mimeType, fileName)
}

/// Media our Backends can decode — and only inside a page (WebEngine turns a
/// top-level navigation to local media into a fresh Download instead of
/// playing it; see BrowserDownloadOpenContext.mediaPlayerPageUrl).
///
/// MP4/M4A/AAC are deliberately absent: the shipped Chromium is built without
/// proprietary codecs (a WebEngine build quirk), so H.264/AAC fail with
/// DEMUXER_ERROR_NO_SUPPORTED_STREAMS and would leave the user staring at a
/// dead player. They go to the OS instead, as do Ogg and Matroska. Revisit if
/// the build ever gains those codecs.
function isPlayableMedia(mimeType, fileName) {
    const mime = String(mimeType || "").toLowerCase()
    const name = String(fileName || "").toLowerCase()

    if (mime === "audio/mpeg" || mime === "audio/mp3" || name.endsWith(".mp3"))
        return true
    if (mime === "audio/wav" || mime === "audio/x-wav" || mime === "audio/wave"
            || name.endsWith(".wav"))
        return true
    if (mime === "video/webm" || mime === "audio/webm" || name.endsWith(".webm"))
        return true
    return false
}

/// Audio/video split for the player page: audio/* is never video; video/* and
/// bare ".webm" get a <video> element (WebEngine renders webm video there,
/// and an audio-only webm still plays in a <video> tag).
function isVideoMedia(mimeType, fileName) {
    const mime = String(mimeType || "").toLowerCase()
    const name = String(fileName || "").toLowerCase()
    if (mime.startsWith("audio/"))
        return false
    return mime.startsWith("video/") || name.endsWith(".webm")
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
