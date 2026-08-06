// Media page behaviour for media_player.html.
//
// Playback itself needs no script — the element is rendered with `controls`, so
// the page still works with JavaScript disabled. This only replaces a control
// that cannot decode its source with a readable line: BrowserDownloadOpenContext
// keeps undecodable types off the in-browser route, but a truncated or
// mislabelled file still reaches us.

(function () {
    var media = document.getElementById("media")
    var failed = document.getElementById("failed")
    if (!media || !failed)
        return

    media.addEventListener("error", function () {
        media.hidden = true
        failed.hidden = false
    })
})()
