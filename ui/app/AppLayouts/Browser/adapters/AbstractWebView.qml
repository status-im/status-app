import QtQuick

import AppLayouts.Browser.stores as BrowserStores

Item {
    id: root

    required property BrowserStores.BookmarksStore bookmarksStore
    required property var localAccountSensitiveSettings

    required property var webChannel
    required property ProfileParams profileParams
    required property bool devToolsEnabled
    required property bool enableJsLogs

    readonly property bool offTheRecord: profileParams.offTheRecord

    // === State Properties ===
    property url url: ""
    property string uid: ""
    readonly property string title: ""
    readonly property bool loading: false
    readonly property bool canGoBack: false
    readonly property bool canGoForward: false
    readonly property real loadProgress: 0
    readonly property real zoomFactor: 1.0
    readonly property var history: null
    readonly property url icon: ""
    readonly property bool htmlPageLoaded: false
    readonly property var scrollPosition: Qt.point(0, 0)

    // True while at least one data-clearing operation is in flight (see CONTEXT: Clearing).
    property bool clearing: false

    // === Capability Flags ===
    required property bool supportsZoom
    required property bool supportsDevTools
    required property bool supportsFindInPage
    required property bool supportsIncognito
    required property bool supportsHistory
    required property bool hasNativeFindPanel

    // Whether "clear current site data" is available on this platform/backend.
    // Desktop: always true (JS path). Mobile: reflects native capability.
    property bool clearSiteDataSupported: false

    // Mobile-only: pauses native webview updates (no-op on desktop)
    property bool freeze: false

    // Tab strip gone but Web View kept alive for non-terminal Downloads (ADR 0006 §6).
    // Retained Views take no new Downloads or retries.
    property bool retained: false

    // Opened by a page (target=_blank / window.open) and never committed a page of
    // its own — the one fact that makes a Tab download-only (ADR 0006 §6).
    property bool pristinePopup: false

    readonly property int devToolsHeight: 400

    readonly property int findBackward: 1
    readonly property int findCaseSensitively: 2

    // === Web Actions (constants for cross-platform compatibility) ===
    // These map to WebEngineView.WebAction enum on desktop
    enum WebAction {
        NoWebAction = -1,
        Back = 0,
        Forward = 1,
        Stop = 2,
        Reload = 3,
        Cut = 4,
        Copy = 5,
        Paste = 6,
        Undo = 7,
        Redo = 8,
        SelectAll = 9,
        PasteAndMatchStyle = 10,
        RequestClose = 35
    }

    // === Download States (constants for cross-platform compatibility) ===
    // WebEngine-shaped numbering (0–4); Paused = 5 matches MobileWebViewDownload.
    // Both adapters map Backend downloads into this seam — UI never branches on Backend.
    enum DownloadState {
        DownloadRequested = 0,
        DownloadInProgress = 1,
        DownloadCompleted = 2,
        DownloadCancelled = 3,
        DownloadInterrupted = 4,
        DownloadPaused = 5
    }

    // === JavaScript Dialog Types (constants for cross-platform compatibility) ===
    // These map to JavaScriptDialogRequest.DialogType enum on desktop
    enum JavaScriptDialogType {
        DialogTypeAlert = 0,
        DialogTypeConfirm = 1,
        DialogTypePrompt = 2,
        DialogTypeUnload = 3
    }

    signal linkHovered(string hoveredUrl)
    signal windowCloseRequested()
    signal downloadRequested(var download)
    /// Long-press on a link/image (mobile Backends; WebEngine has its own menu).
    /// Either URL may be empty, never both. position is view-local logical px.
    signal linkLongPressed(url linkUrl, url imageUrl, point position)
    signal devToolsToggled(bool enabled)

    // Signals to be handled at Layout level
    // newWindowRequested passes ready-to-use parameters for tab creation:
    // - makeCurrent: whether to switch to the new tab immediately
    // - requestedUrl: the URL to load
    // - callback: function to call with the created tab (handles acceptAsNewWindow internally)
    signal newWindowRequested(bool makeCurrent, url requestedUrl, var callback)
    signal certificateError(var error)
    signal javaScriptDialogRequested(var request)
    signal findTextFinished(var result)

    function loadUrl(url) { console.warn("AbstractWebView: loadUrl not implemented") }

    /// Local-file load with a directory read grant (ADR 0006 §8).
    /// Empty readAccessUrl means the file's own directory.
    function loadFileUrl(fileUrl, readAccessUrl) {
        console.warn("AbstractWebView: loadFileUrl not implemented")
    }

    function goBack() { console.warn("AbstractWebView: goBack not implemented") }
    function goForward() { console.warn("AbstractWebView: goForward not implemented") }
    function goBackOrForward(offset) { console.warn("AbstractWebView: goBackOrForward not implemented") }
    function reload() { console.warn("AbstractWebView: reload not implemented") }
    function stop() { console.warn("AbstractWebView: stop not implemented") }

    // Force reload: refetch every resource from the network for this navigation,
    // bypassing (not evicting) the cache (see CONTEXT: Force reload).
    function forceReload() { console.warn("AbstractWebView: forceReload not implemented") }

    // Clear current site data: wipe the current tab's site data, then reload.
    // The implementation reloads itself; callers must not reload afterwards.
    function clearSiteData() { console.warn("AbstractWebView: clearSiteData not implemented") }

    // Clear browsing data (profile-wide cache, cookies, DOM storage), then reload.
    function clearBrowsingData() { console.warn("AbstractWebView: clearBrowsingData not implemented") }

    // Run JS in the current page. Optional callback receives the result (WebEngine).
    function runJavaScript(script, callback) { console.warn("AbstractWebView: runJavaScript not implemented") }

    function findText(text, flags) {}
    function showFindPanel() {}
    function hideFindPanel() {}
    function changeZoomFactor(factor) {}
    function acceptAsNewWindow(request) {}
    function detachView() {}

    function triggerWebAction(action) { console.warn("AbstractWebView: triggerWebAction not implemented") }

    /// Host-side re-issue of a Download (Retry). MobileWebView: backend.downloadUrl;
    /// WebEngine: BrowserProfileUtils → QWebEnginePage::download (not navigate).
    function downloadUrl(url, suggestedFileName) {
        console.warn("AbstractWebView: downloadUrl not implemented")
    }
}
