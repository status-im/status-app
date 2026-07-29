# Browser — Context Glossary

The in-app browser: tabs, navigation, favourites, and downloads, on desktop
(Qt WebEngine) and mobile (the MobileWebView library). Definitions only — no
implementation details.

Terms owned by the library rather than by this layer (Storage Profile, Standard
and Incognito mode, Clearing, Freeze, Download, Download Request, Download
Target, Download State, Inline Download) are defined in the MobileWebView
glossary and are not repeated here. See [CONTEXT-MAP.md](../../../../CONTEXT-MAP.md).

## Browsing

### Tab
One entry in the tab strip, backed by exactly one Web View for its lifetime.
Closing a Tab destroys its Web View unless the view is Retained.

### Web View
The surface that loads and renders one page and owns that page's navigation
history. Its capabilities (zoom, find, dev tools, incognito, site-data clearing)
vary by platform and are reported rather than assumed.
_Avoid_: webview instance, browser view, page.

### Backend
The platform engine behind a Web View: Qt WebEngine on desktop, MobileWebView on
mobile. Which Backend is in use is never a UI concern — only its reported
capabilities are.

### Session
The set of open Tabs, their order, and the active Tab, persisted so the browser
reopens where the user left it. Opt-in; independent of Download History.

### Downloads Page
A Tab that shows the Downloads List instead of a web page. Desktop only.
_Avoid_: downloads tab, download view.

## Downloads

### Download Record
This layer's own record of one download: source URL, file name, Download Target,
size, start time, and final Download State. A Record outlives the library's
Download object and is the identity the Downloads List and Download History are
built from.
_Avoid_: download item, download entry, download model.

### Download History
The persisted set of Download Records, restored on launch and capped in size.
Holds Records only — never file bytes, and never Records from Incognito Tabs.
_Avoid_: downloads log, saved downloads.

### Downloads List
The full, scrollable view of Download Records, newest first, with the per-Record
actions (open, show in folder, share, retry, pause/resume, cancel).
_Avoid_: downloads panel, downloads modal.

### Download Pill
The compact strip entry shown while a download is worth surfacing in-line: file
name, progress or terminal status, one primary action, and a menu. Lives for the
browsing session only and is never restored from Download History.
_Avoid_: download chip, download tab, download bar item.

### Retained View
A Web View kept alive, hidden and frozen, after its Tab is gone, because it still
owns a non-terminal Download. Destroyed once every Download it owns reaches a
terminal state.
_Avoid_: zombie tab, orphan view, background tab.

### Missing File
A Download Record whose Download Target no longer exists on disk. Still a valid
Record — its source URL remains actionable — but it cannot be opened or shared.
_Avoid_: broken download, deleted download.
