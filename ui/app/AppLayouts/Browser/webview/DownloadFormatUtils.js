.pragma library

// Pure format predicates for Download Records (ADR 0006 §8).
//
// Every input is a plain value — (mimeType, fileName, supportsPdf, …) — with
// no QML object access, so BrowserDownloadOpenContext and QML components can
// share one allowlist. supportsPdf is the Backend's PDF-rendering Capability;
// mediaPlaybackSupported is the platform's in-page playback gate. Both are
// passed in, never probed here.

// The enumerated safe sets, one pair per branch of canOpenInBrowser. The
// extensions are the operative half; the MIME types only answer for a name
// that carries no extension at all.
const _IMAGE_MIME_TYPES = ["image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp"]
const _IMAGE_EXTENSIONS = ["png", "jpg", "jpeg", "gif", "webp", "bmp"]
const _TEXT_MIME_TYPES = ["text/plain"]
const _TEXT_EXTENSIONS = ["txt"]
const _PDF_MIME_TYPES = ["application/pdf"]
const _PDF_EXTENSIONS = ["pdf"]

/// Open-in-Browser allowlist: types our Backends render (ADR 0006 §8).
/// Raster images and plain text; PDF when the Backend supports it; media per
/// isPlayableMedia, gated by mediaPlaybackSupported. Everything else is handed
/// to the OS.
///
/// Default-deny, and enumerated on purpose. A Download opens in an isolated
/// local-preview profile — ephemeral, no injected scripts, no web channel, and
/// unreachable from any browsing Tab — but that profile is containment, not
/// permission: the allowlist stays the first line of defense, and only formats
/// that cannot execute a script in a web view belong on it. No prefix match, no
/// character-class extension pattern — a family match ("every image/*") lets the
/// next scriptable member of that family in behind it.
/// SVG, HTML and XHTML are deliberately absent: WebEngine runs their scripts.
/// In-app viewing for those comes back through the native viewer follow-up,
/// which renders them outside a web engine altogether — never by widening this
/// list.
///
/// The extension decides, not the Record's MIME type, because that is what
/// decides in the Tab: a file:// navigation is rendered by extension, so
/// "evil.html" served as image/png is a page whatever the server called it. A
/// name that carries an extension passes only on that extension; the MIME type
/// answers alone only for a name that carries none. A leading-dot name carries
/// one — ".html" is html, not a base name — or the MIME branch would answer for
/// a file the Tab would still render as a page.
///
/// Order matters and is behavior: a name ending in ".pdf" resolves on the
/// PDF branch even if its MIME type would also match media.
function canOpenInBrowser(mimeType, fileName, supportsPdf, mediaPlaybackSupported = true,
                          proprietaryCodecs = false) {
    const mime = String(mimeType || "").toLowerCase()
    const name = String(fileName || "").toLowerCase()
    const ext = _extensionOf(name)

    if (_allows(mime, ext, _IMAGE_MIME_TYPES, _IMAGE_EXTENSIONS))
        return true
    if (_allows(mime, ext, _TEXT_MIME_TYPES, _TEXT_EXTENSIONS))
        return true
    if (_allows(mime, ext, _PDF_MIME_TYPES, _PDF_EXTENSIONS))
        return !!supportsPdf
    // Media follows the same rule. Rather than restate its containers here,
    // isPlayableMedia is asked about the name alone whenever there is an
    // extension to answer with — its own enumeration stays the single one.
    return !!mediaPlaybackSupported
            && isPlayableMedia(ext ? "" : mime, name, proprietaryCodecs)
}

/// One branch of the allowlist: the name's extension must be one of the
/// branch's own, or — for a name without an extension — the MIME type must be.
function _allows(mime, ext, mimeTypes, extensions) {
    if (ext)
        return extensions.indexOf(ext) >= 0
    return mimeTypes.indexOf(mime) >= 0
}

/// The extension of a (lowercased) file name, without its dot, or "" when the
/// name carries none. Trailing dots and spaces come off first: Windows drops
/// them when it opens the file, so "evil.html." is an .html there.
/// A leading-dot name is all extension and no base: ".html" is html.
function _extensionOf(name) {
    let end = name.length
    while (end > 0 && (name[end - 1] === "." || name[end - 1] === " "))
        --end
    const trimmed = name.substring(0, end)
    const dot = trimmed.lastIndexOf(".")
    if (dot < 0)
        return ""
    return trimmed.substring(dot + 1)
}

/// Media our Backends can decode — and only inside a page (WebEngine turns a
/// top-level navigation to local media into a fresh Download instead of
/// playing it; see BrowserDownloadOpenContext.mediaPlayerPageUrl).
///
/// MP4/M4A/AAC ride on proprietaryCodecs: our Qt WebEngine build carries no
/// H.264/AAC and fails them with DEMUXER_ERROR_NO_SUPPORTED_STREAMS, while
/// WebKit and the Android WebView decode them natively. Ogg and Matroska stay
/// out everywhere (platform media stack). A format left out opens in the OS.
function isPlayableMedia(mimeType, fileName, proprietaryCodecs = false) {
    const mime = String(mimeType || "").toLowerCase()
    const name = String(fileName || "").toLowerCase()

    if (mime === "audio/mpeg" || mime === "audio/mp3" || name.endsWith(".mp3"))
        return true
    if (mime === "audio/wav" || mime === "audio/x-wav" || mime === "audio/wave"
            || name.endsWith(".wav"))
        return true
    if (mime === "video/webm" || mime === "audio/webm" || name.endsWith(".webm"))
        return true
    if (proprietaryCodecs) {
        if (mime === "video/mp4" || name.endsWith(".mp4") || name.endsWith(".m4v"))
            return true
        if (mime === "audio/mp4" || mime === "audio/aac" || mime === "audio/x-m4a"
                || name.endsWith(".m4a") || name.endsWith(".aac"))
            return true
    }
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
            || name.endsWith(".mp4") || name.endsWith(".m4v")
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
