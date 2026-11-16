# Browser — Context Glossary

The in-app browser: tabs, navigation, favourites, and downloads, on desktop
(Qt WebEngine) and mobile (the MobileWebView library). Definitions only — no
implementation details.

Terms owned by the library rather than by this layer (Storage Profile, Standard
and Incognito mode, Clearing, Freeze, Download, Download Request, Download
Target, Download State, Inline Download) are defined in the MobileWebView
glossary and are not repeated here.

## Browsing

### Tab
One entry in the tab strip, backed by exactly one Web View for its lifetime.
Closing a Tab destroys its Web View unless the view is Retained, and never
cancels that view's Downloads.

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

### Drop
Giving back the memory of a Web View, or of the whole browser, that is not on
screen, while the user loses nothing they can see: the Tabs, their order, the
active Tab and each Tab's back/forward history stay, and a dropped page loads
again when its Tab is next shown. Happens a while after the browser leaves the
screen, sooner when the system is short of memory, and at once when no Tab
shows a page. Only the active Tab loads on return.
_Avoid_: unload, suspend, discard, hibernate.

### Keep-alive reason
Something a Web View is doing for the user that a Drop would break: a
non-terminal Download, a dApp request awaiting the user's answer, audible
media, or camera or microphone use. A Web View with a Keep-alive reason is
never dropped, and keeps the browser around it; the others are still dropped.
_Avoid_: pin, lock, busy.

## Downloads

### Download Record
This layer's own record of one download: source URL, file name, Download Target,
size, start time, and final Download State. A Record outlives the library's
Download object and is the identity the Downloads List and Download History are
built from.
_Avoid_: download item, download entry, download model.

### Download History
The persisted set of Download Records, restored on launch and capped in size,
oldest evicted first and never a Record whose Download is still non-terminal.
Holds Records only — never file bytes, and never Records from Incognito Tabs.
_Avoid_: downloads log, saved downloads.

### Downloads List
The full, scrollable view of Download Records, newest first, with the per-Record
actions (open, show in folder, share, retry, pause/resume, cancel). Lives as the
third section of the Open tabs overview on both Desktop and Mobile — never as its
own Tab.
_Avoid_: downloads panel, downloads modal, Downloads Page, downloads tab,
download view.

### Download Pill
The compact strip entry shown while a download is worth surfacing in-line: file
name, progress or terminal status, one primary action, and a menu. Lives for the
browsing session only, is never restored from Download History, and never
outlives its Record's place in the Downloads List.
_Avoid_: download chip, download tab, download bar item.

### Retained View
A Web View kept alive, hidden and frozen, after its Tab is gone, because it still
owns a non-terminal Download. Destroyed once every Download it owns reaches a
terminal state. Exists only when destroying the Web View would abort those
Downloads — today that is the Mobile Backend; a Backend that keeps Downloads
alive after view destruction does not create Retained Views. Incognito Tabs are
retained on the same terms: retention keeps a transfer the user asked for alive
and persists nothing. A Retained View is not part of the Tab set and never takes
on new Downloads — it only finishes the ones it already owns.
_Avoid_: zombie tab, orphan view, background tab.

### Missing File
A Download Record whose Download Target no longer exists on disk. Still a valid
Record — its source URL remains actionable — but it cannot be opened or shared.
_Avoid_: broken download, deleted download.
