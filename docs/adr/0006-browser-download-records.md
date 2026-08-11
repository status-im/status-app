# ADR 0006: Browser downloads — Download Records over live library objects

## Status

Accepted

- **Date**: 2026-07-29
- **Amended**: 2026-07-30 — §6 (no close-confirmation; retention ownership and
  bounds), §7 (profile match is mandatory), §8 (unreportable state must not gate
  UI; allowlist limited to uniformly-rendered media; opening prefers our browser
  and falls back to the OS; desktop copies a file path)
- **Amended**: 2026-08-07 — §8 (in-page media playback is a Capability the Backend
  answers at runtime, not a platform check or a deployment floor; the licensed
  codecs are a Capability too, so the allowlist is per Backend; needing the
  player page is a Capability as well, and Backends without it load the media
  file directly)
- **Amended**: 2026-08-11 — §8 (a Tab displaying a downloaded file is isolated
  from browsing: its own ephemeral profile, no scripts, no channel, and the only
  profile that may reach `file://`; browsing profiles reach none)
- **Amended**: 2026-08-11 — §7 (a re-issue carries a correlation token the
  Backend echoes, so it reattaches to the armed Record by identity; the desktop
  re-issue is viewless — the profile, not a Tab, owns the Backend — while mobile
  still needs a live Tab, and neither a Retained View nor a local preview is one)
- **Owners**: Status Desktop (browser)

## Context

Mobile had no downloads at all: `MobileWebViewAdapter.qml` never connected the
backend's `downloadRequested` signal, and the download bar was gated off entirely
(`sourceComponent: !root.isMobile ? downloadBar : null`). The MobileWebView
library closed that gap upstream (its ADR 0005, shipped at `a09833d`): a Download
is surfaced to the host as a `MobileWebViewDownload` with metadata only, the host
supplies a **Download Target** and calls `accept(target)`, and the library then
performs and tracks the transfer with pause/resume/cancel/retry.

Two properties of that surface do not fit the download UI we have:

- **Ownership is per Backend and terminal-bounded.** There is no cross-view
  registry, and `DownloadRegistry` calls `download->deleteLater()` the moment a
  Download reaches Completed, Cancelled, or Interrupted. Its comment reads "host
  (DownloadsStore) may still hold a ref and call retry()", but a QML reference
  does not keep a C++ `QObject` alive: one event-loop turn later the object is
  gone and the QML variable reads as null. Anything the UI must still show or act
  on *after* a download finishes cannot be the library's object.
- **The host owns the destination.** Android scoped storage and the iOS sandbox
  mean the library never picks a path; with no accept, a Download is cancelled.

Meanwhile the existing store held raw platform objects in a `ListModel` *and* a
parallel `downloads: []` JS array, because `ListModel.append(qobject)` copies
property values and does not track later changes — so the model was effectively
only supplying `count` and `index`.

The mobile design then raised the bar past anything the old store could express:
a downloads strip under the address bar, a full list inside the tabs/bookmarks
panel, per-state menus (Show in folder / Pause / Resume / Cancel / Share file /
Share URL / Open in Browser), duplicate-name suffixes (`(1)`, `(2)`), and — from
the product discussion — a **durable** list, so that show-in-folder, copy-URL and
retry still work later, with entries struck through once their file is gone.

## Decision

**A Download Record, owned by this layer, is the identity of a download; the
library's Download object is a transient attachment to it.**

1. **One platform-neutral seam.** `AbstractWebView` defines the Download shape;
   both adapters map into it — `MobileWebViewDownload` on mobile,
   `WebEngineDownloadRequest` on desktop. `DownloadState` keeps WebEngine's
   numbering and adds `Paused = 5`, matching the library. No UI code branches on
   which Backend produced a download.

2. **Download Records own the list.** `DownloadsStore` holds Records as objects
   (not `ListModel` rows), so delegates bind to a Record directly and the
   parallel-array workaround disappears. A live Download attaches to its Record
   while it exists and supplies progress and pause/resume/cancel; everything that
   must survive the transfer lives on the Record.

3. **Download History is persisted, in the same place as the Tab session.**
   Records are written through the browser preferences key/value store under their
   own category, debounced, and only on two events: Record creation and the
   terminal transition. Progress is never persisted. The History is capped at 200
   Records, oldest evicted — each write rewrites the whole JSON blob, so unbounded
   growth is a real cost. A Record restored without a terminal state means the app
   died mid-transfer; it is restored as **Interrupted**, because the library does
   not survive process death and no progress will ever arrive for it.

4. **Incognito downloads never enter Download History.** They appear in the
   current session only. The library already refuses to register Incognito
   downloads with the Android system Downloads UI precisely so that those URLs do
   not leak; persisting source URL and target path host-side would undo that in the
   most sensitive place. The file on disk stays — that was the user's explicit act.

5. **The Download Target is fixed host policy**: the platform downloads location,
   file name from the library's suggestion, collisions resolved with `(1)`, `(2)`
   suffixes. No save-as picker: the design starts the transfer immediately and
   shows a pill, and there is nowhere to store a per-download choice yet.

6. **Retained Views instead of cancelled downloads.** A Web View whose Tab goes
   away while it still owns a non-terminal Download is hidden and frozen rather
   than destroyed, and destroyed once its downloads are terminal. The library
   guarantees a Download keeps running while its view is frozen, so this is the
   only option that neither lies about ownership nor breaks Inline Downloads,
   whose bytes live in the originating Backend and cannot be re-issued elsewhere.
   This matters most for the download-only Tab (`target=_blank` onto an
   attachment), which the browser closes *itself* — there is no user to prompt.

   **Closing a Tab never cancels a Download** — user-initiated or not. An earlier
   draft asked for confirmation on user close and cancelled on confirm; that was
   dropped, because the Download Pill and the Downloads List already offer Cancel
   for every non-terminal Download, so the dialog asks a question the user can
   answer better, later, and with more context. Cancelling stays an explicit act
   on the download, never a side effect of tidying up tabs.

   Retention rules:
   - **One owner.** The component that creates Web Views destroys them
     (`BrowserWebViewContext`), retained or not. `DownloadsStore` answers "does
     this view still own non-terminal Downloads?" and signals when that becomes
     false; only a Download Record ever attaches to a live Download object.
   - **Retained Views take no new work.** A Retained View is not part of the Tab
     set and is never chosen as the Backend for a new Download or a retry —
     otherwise its retention could be extended indefinitely and "destroyed once
     its Downloads are terminal" would stop being a reachable state.
   - **Incognito Tabs are retained on the same terms.** The privacy boundary is
     persistence (§4), not aborting a transfer the user explicitly asked for;
     retention writes nothing.
   - **No timeout and no cap.** Retention ends only when the Downloads it holds
     reach a terminal state. A host-side timeout would report a live transfer as
     dead; a stalled transfer is the Backend's to interrupt, and the user's to
     cancel from the Pill.

7. **Retry is a host-side re-issue**, not the library's `retry()`: the Record's
   URL is downloaded again via `downloadUrl(url, fileName, token)` on a Backend
   owned by a matching profile. Offered from the Record menu for Interrupted and
   Cancelled Records, and on tap for Interrupted only — tapping a download the
   user cancelled must not restart it. Inline Downloads get no retry at all;
   their payload is not reproducible from a URL.

   **The profile match is mandatory, never best-effort.** Re-issuing an Incognito
   Record on a Standard Backend would give the new Record standard mode, and so
   persist an Incognito source URL into Download History and — on Android —
   register the file with the system Downloads UI, which the library refuses for
   Incognito precisely to keep those URLs out. If no Backend with a matching mode
   exists, retry is unavailable rather than downgraded.

   **A re-issue is correlated by a token, not by URL and timing.** The store mints
   a token when it arms the Retry, the Backend echoes it back on the Download
   Request it raises, and the host attaches the new transfer to the armed Record
   by that identity. Without it an unrelated Download of the same URL, arriving in
   the same window, would capture the arm and the Retry would land on the wrong
   Record — or a second History row. A Download Request carrying no token is an
   ordinary one.

   **Which Backend runs it is the host's business, and needs no Tab.** On desktop
   the re-issue is viewless: `ProfileManager` resolves the profile from the
   Record's mode and `downloadUrl` runs on a transient page that profile owns, so
   a Retry survives closing every Tab. Mobile has no such page — there the
   Backend *is* the native view — so it needs a live Tab on a matching profile:
   never a Retained View, which finishes only the Downloads it already owns (§6),
   and never a local preview, whose isolated profile (§8) is not a browsing
   profile and would fail the match above.

8. **Platform reach is reported, not assumed.** "Show in folder" exists on
   Android only (via the system downloads view; the library registers completed
   Standard-mode files with MediaStore) and is hidden on iOS, which has no folder
   to show. "Share file" reuses the existing cross-platform share sheet
   (`SystemUtilsInternal.sharePaths`). "Open in Browser" is gated on the Backend's
   ability to render the file's type: images, plain text and HTML everywhere, PDF
   only where the Backend renders PDF — the system Android WebView does not.

   **The allowlist admits formats our Backends render.** Audio and video qualify
   to the extent the Backend decodes them — MP3, WAV and WebM are in everywhere;
   Ogg and Matroska stay out everywhere (platform media stack). M4A/AAC and
   MP4/H.264 follow a Capability instead: our Qt WebEngine build carries no
   licensed codecs and fails them with `DEMUXER_ERROR_NO_SUPPORTED_STREAMS`,
   while WebKit and the Android WebView decode them natively. A format left out
   is not a dead end: it opens in the OS instead.

   **Whether a page can play media at all is a Capability, not a platform check.**
   The allowlist says which formats a Backend renders; the Backend still has to
   say whether in-page playback works for it, and it answers at runtime. iOS is
   the case that forces this — WebKit gained WebM/VP8/VP9 in 17.4 — and the
   answer belongs in the library rather than in the app's deployment floor:
   raising the floor would drop every older device to buy one format, and hiding
   the question behind `isIOS` in the UI would state a platform fact the platform
   is perfectly able to state itself. A "no" takes the same route an unlisted
   format takes, out to the OS.

   **The player page is a workaround, so needing one is a Capability too.** The
   page exists only because WebEngine turns a top-level navigation to local
   audio/video into a fresh Download instead of playing it; WebKit and the
   Android WebView give the same file a native player. Keeping the page
   everywhere is what broke iOS playback: it sits in `TempLocation` while the
   media sits in the downloads directory, and a plain local load grants the web
   content process only the file it was handed, so the page came up and the media
   never loaded. Backends needing no page load the media file itself through
   `loadFileUrl(fileUrl, readAccessUrl)`, its grant left empty and so resolving
   to the file's own directory — the narrowest one that works. That entry point
   joins the seam beside `loadUrl`, proxied by the decorator — the seam's
   easiest member to forget.

   **Opening a finished Download prefers our own browser, and hands off when it
   cannot render.** Tapping a Completed Record — from the Downloads List or its
   Pill — loads it in a Tab when the type is on the allowlist, and otherwise asks
   the OS to open it. The fallback is what makes the allowlist affordable: keeping
   it narrow costs the user nothing, so there is never a reason to widen it by
   guessing.

   **The desktop file action copies a path, and says so.** Where mobile shares the
   file itself through the system sheet, desktop has no file to hand anywhere — it
   can only name the file's location. The action is therefore "Copy file path" and
   yields the plain filesystem path, which a terminal or a file manager resolves.
   Our own address bar does not, by the rule below.

   **A Tab showing a downloaded file is not a browsing Tab.** It gets local-preview
   profile params: an ephemeral profile of its own, no injected scripts, no web
   channel, no connector — and it is the only profile allowed to reach `file://`,
   under the downloads and player-page directories alone. Browsing profiles reach
   no local file at all, so a path typed in the address bar dead-ends. Splitting
   the profile is what makes that affordable: with one profile for both, opening a
   downloaded file meant leaving a filesystem door open to every site the user
   visits, and closing it meant not opening the file. The isolation is one flag on
   the params, so a preview Tab's params can never seed a browsing Tab.

   The corollary: **state the Backend cannot report must not gate UI.** The seam
   can open and close the native find panel but is never told when the user
   dismisses it, so "Find is open" is not a fact the host owns. Opening Find
   therefore hides the Download Pill strip once, as an action, instead of latching
   it hidden until some unrelated event happens to clear the flag.

9. **Clear browsing data clears Records, not files.** Downloaded files are the
   user's; the browsing trace is ours to erase.

## Consequences

### Positive

- One download vocabulary from the seam up: the same store, Records, list and
  menus serve desktop and mobile, and the desktop store loses its parallel-array
  workaround.
- The list is honest after a transfer ends, after a Tab closes, and after a
  restart — none of which the library's object lifetime can span.
- Downloads no longer die silently when the browser closes the tab that started
  them, which was the most common mobile trigger.

### Negative / trade-offs

- **Retained Views are a real cost.** A hidden native WebView can outlive its Tab,
  and its lifetime is now driven by download state. Leaks here are invisible to the
  user, so ownership has to stay in one place. With no cap and no timeout, several
  attachments opened in a row can leave several hidden native views alive at once;
  that ceiling is set by user behaviour and by how quickly the Backend interrupts a
  stalled transfer, not by us.
- **Host-side retry loses the library's resume path.** A re-issued download starts
  from zero rather than reusing WKDownload resume data or an HTTP `Range` request.
  A follow-up upstream would fix the root cause: keep a terminal Download alive
  until the host releases it, or expose `retryById()` on the Backend.
- **The persisted Record format becomes a compatibility surface.** It must tolerate
  reading what older builds wrote, and vice versa.
- **On iOS the downloaded file is invisible outside the app.** Without
  `UIFileSharingEnabled` (deliberately not enabled here — it exposes the whole app
  sandbox and is a product decision, not a download feature) the only route to the
  file is the share sheet.

## Scope

Out of scope for this decision: resuming a transfer after process death, a
foreground download service, a save-as picker or per-download target, and any
change to how the library itself transfers bytes.
