# ADR 0006: Browser downloads — Download Records over live library objects

## Status

Accepted

- **Date**: 2026-07-29
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
   A user-initiated close of a Tab with an active Download asks for confirmation,
   and confirming cancels the Download.

7. **Retry is a host-side re-issue**, not the library's `retry()`: the Record's
   URL is downloaded again via `downloadUrl(url, fileName)` on a Backend with a
   matching profile. Offered from the Record menu for Interrupted and Cancelled
   Records, and on tap for Interrupted only — tapping a download the user
   cancelled must not restart it. Inline Downloads get no retry at all; their
   payload is not reproducible from a URL.

8. **Platform reach is reported, not assumed.** "Show in folder" exists on
   Android only (via the system downloads view; the library registers completed
   Standard-mode files with MediaStore) and is hidden on iOS, which has no folder
   to show. "Share file" reuses the existing cross-platform share sheet
   (`SystemUtilsInternal.sharePaths`). "Open in Browser" is gated on the Backend's
   ability to render the file's type: images, plain text and HTML everywhere, PDF
   only where the Backend renders PDF — the system Android WebView does not.

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
  user, so ownership has to stay in one place.
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
