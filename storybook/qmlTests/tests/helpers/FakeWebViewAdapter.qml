import QtQuick

/// Stand-in for the adapter LazyWebViewAdapter loads, with no QtWebEngine
/// import. Point adapterPath at it with Qt.resolvedUrl().
Item {
    id: root

    // Set by LazyWebViewAdapter.ensureLoaded() through setSource properties.
    property var profileParams: null
    property string uid: ""
    property var bookmarksStore: null
    property var webChannel: null
    property bool enableJsLogs: false
    property var localAccountSettings: null
    property bool devToolsEnabled: false
    property bool freeze: false
    property var profileManager: null

    // Proxied state LazyWebViewAdapter reads back.
    property url url: ""
    property string title: ""
    property url icon: ""
    property bool htmlPageLoaded: false
    property bool loading: false
    property bool canGoBack: false
    property bool canGoForward: false
    property real loadProgress: 0
    property real zoomFactor: 1.0
    property var history: null
    property var scrollPosition: Qt.point(0, 0)
    property bool clearing: false
    property bool playingAudio: false

    property bool supportsZoom: true
    property bool supportsDevTools: true
    property bool supportsFindInPage: true
    property bool supportsIncognito: true
    property bool supportsHistory: true
    property bool hasNativeFindPanel: false
    property bool clearSiteDataSupported: true

    // LazyWebViewAdapter's Connections block warns on any it cannot find.
    signal linkHovered(string hoveredUrl)
    signal windowCloseRequested()
    signal downloadRequested(var download, string token)
    signal linkLongPressed(url linkUrl, url imageUrl, point position)
    signal newWindowRequested(bool makeCurrent, url requestedUrl, var callback)
    signal certificateError(var error)
    signal javaScriptDialogRequested(var request)
    signal findTextFinished(var result)
    signal devToolsToggled(bool enabled)
    signal renderProcessTerminated(int status, int exitCode, bool willRevive)

    property int reloadCalls: 0
    property var loadedUrls: []
    property int detachCalls: 0
    // Back/forward history as the Backend would hand it out, and what it was given.
    property var savedState: null
    property var restoredStates: []
    // What reached the Backend, in order: "restore" and "url:<url>".
    property var calls: []
    onUrlChanged: root.calls = root.calls.concat(["url:" + root.url])

    function reload() { root.reloadCalls += 1 }
    function loadUrl(u) { root.url = u; root.loadedUrls = root.loadedUrls.concat([String(u)]) }
    property var fileLoads: []
    function loadFileUrl(fileUrl, readAccessUrl) {
        root.fileLoads = root.fileLoads.concat([String(fileUrl) + "|" + readAccessUrl])
        root.url = fileUrl
    }
    function goBack() {}
    function goForward() {}
    function goBackOrForward(offset) {}
    function stop() {}
    function forceReload() {}
    function detachView() { root.detachCalls += 1 }
    function saveState() { return root.savedState }
    property int terminateRendererCalls: 0
    function terminateRenderer() { root.terminateRendererCalls += 1 }
    function restoreState(state, fallbackUrl) {
        root.restoredStates = root.restoredStates.concat([state])
        root.calls = root.calls.concat(["restore"])
        if (fallbackUrl && fallbackUrl.toString())
            root.url = fallbackUrl
    }
    function triggerWebAction(action) {}
    function runJavaScript(script, callback) {}

    /// Convenience: the Backend values a WebEngine crash reports.
    function simulateCrash(willRevive) {
        root.renderProcessTerminated(2 /*Crashed*/, 133, !!willRevive)
    }
    /// The system killed the renderer (low memory), the page did nothing wrong.
    function simulateKill(willRevive) {
        root.renderProcessTerminated(3 /*Killed*/, 0, !!willRevive)
    }
}
