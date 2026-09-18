.pragma library

/// The User-Agent a Web View sends: the engine's own string without the
/// embedded-WebView markers, plus a Status product token — the way Edge adds
/// "Edg/" and Opera "OPR/" to Chrome's. An unknown engine default stays empty,
/// so the engine keeps its own string.
function honestUserAgent(engineDefault, appVersion) {
    let ua = String(engineDefault || "").trim()
    if (!ua)
        return ""

    ua = ua.replace(/\s+QtWebEngine\/\S+/, "")            // desktop Qt WebEngine
           .replace(/; wv\)/, ")")                           // Android WebView
           .replace(/\s+Version\/4\.0(?=\s+Chrome\/)/, "")   // Android WebView

    // WKWebView leaves out the Safari token that every iOS browser sends.
    if (/AppleWebKit\//.test(ua) && !/Safari\//.test(ua))
        ua += " Safari/604.1"

    const version = /^v?(\d+(?:\.\d+)*)/.exec(String(appVersion || ""))
    return version ? ua + " Status/" + version[1] : ua
}
