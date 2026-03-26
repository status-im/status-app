import QtQuick

Item {
    id: root

    required property var webChannel
    required property ProfileParams profileParams
    property bool devToolsEnabled: false
    property bool isDownloadView: false

    readonly property bool offTheRecord: profileParams.offTheRecord

    // === State Properties ===
    property url url: ""
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

    // === Capability Flags ===
    readonly property bool supportsZoom: false
    readonly property bool supportsDevTools: false
    readonly property bool supportsFindInPage: false
    readonly property bool supportsIncognito: false
    readonly property bool supportsHistory: false
    readonly property bool hasNativeFindPanel: false

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
    // These map to WebEngineDownloadRequest.DownloadState enum on desktop
    enum DownloadState {
        DownloadRequested = 0,
        DownloadInProgress = 1,
        DownloadCompleted = 2,
        DownloadCancelled = 3,
        DownloadInterrupted = 4
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
    function goBack() { console.warn("AbstractWebView: goBack not implemented") }
    function goForward() { console.warn("AbstractWebView: goForward not implemented") }
    function goBackOrForward(offset) { console.warn("AbstractWebView: goBackOrForward not implemented") }
    function reload() { console.warn("AbstractWebView: reload not implemented") }
    function stop() { console.warn("AbstractWebView: stop not implemented") }

    function findText(text, flags) {}
    function showFindPanel() {}
    function hideFindPanel() {}
    function changeZoomFactor(factor) {}
    function acceptAsNewWindow(request) {}
    function detachView() {}

    function triggerWebAction(action) { console.warn("AbstractWebView: triggerWebAction not implemented") }
}
