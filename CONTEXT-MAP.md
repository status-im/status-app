# Context Map

Where the written domain glossaries live. Only the contexts listed here have one;
the rest of the repository documents its vocabulary in code and in
[docs/adr](./docs/adr).

## Contexts

- [Browser](./ui/app/AppLayouts/Browser/CONTEXT.md) — the in-app browser: tabs,
  navigation, favourites, downloads
- [MobileWebView](https://github.com/status-im/mobilewebview/blob/main/CONTEXT.md)
  — the mobile WebView library consumed as a source dependency (see
  `MOBILEWEBVIEW_SOURCE_DIR` and the `FetchContent` declaration in
  `ui/StatusQ/CMakeLists.txt`). Upstream repository, upstream glossary.

## Relationships

- **Browser → MobileWebView**: Browser is the *host*. It consumes the library
  behind its own platform-neutral Web View seam, so that the desktop (Qt
  WebEngine) and mobile paths present the same vocabulary to the UI.
- **Shared language**: Storage Profile, Standard and Incognito mode, Clearing,
  Freeze, Download, Download Request, Download Target, Download State, and Inline
  Download are defined upstream and used unchanged in Browser. Code comments that
  say "see CONTEXT: Clearing" or "see CONTEXT: Force reload" refer to the
  MobileWebView glossary.
- **Host-only language**: Download Record, Download History, Download Pill, and
  Retained View exist only in Browser — the library deliberately has no notion of
  a durable download list, and no cross-view registry.
