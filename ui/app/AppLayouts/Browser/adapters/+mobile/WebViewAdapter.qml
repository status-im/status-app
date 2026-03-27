import QtQuick

import StatusQ.CustomWebView 1.0

import AppLayouts.Browser.stores as BrowserStores

AbstractWebView {
    id: root

    required property BrowserStores.BookmarksStore bookmarksStore
    required property BrowserStores.DownloadsStore downloadsStore
    required property var localAccountSensitiveSettings

    property var findBarComp
    property var favMenu
    property var addFavModal
    property var downloadsMenu
    property var determineRealURLFn: function(url) { return url }
    property bool enableJsLogs: false
    property bool isDownloadView: false

    readonly property bool offTheRecord: false

    property alias url: backend.url
    readonly property alias loading: backend.loading
    readonly property alias title: backend.title
    readonly property alias canGoBack: backend.canGoBack
    readonly property alias canGoForward: backend.canGoForward
    readonly property alias loadProgress: backend.loadProgress
    readonly property alias htmlPageLoaded: backend.loaded

    ListModel {
        id: historyModel
    }

    readonly property var history: ({ items: historyModel })
    readonly property url icon: backend.favicon

    readonly property bool supportsZoom: true
    readonly property bool supportsDevTools: false
    readonly property bool supportsFindInPage: backend.findSupported
    readonly property bool supportsIncognito: false
    readonly property bool supportsHistory: true
    readonly property bool hasNativeFindPanel: backend.hasNativeFindPanel

    readonly property alias zoomFactor: backend.zoomFactor

    MobileWebViewBackend {
        id: backend
        anchors.fill: parent
        visible: root.visible
        userScripts: root.profileParams.scripts
        webChannel: root.webChannel
    }

    Connections {
        target: backend
        function onNewWindowRequested(requestedUrl, userInitiated) {
            const makeCurrent = userInitiated !== false
            root.newWindowRequested(makeCurrent, requestedUrl, function(tab) {
                if (tab && tab.loadUrl)
                    tab.loadUrl(requestedUrl)
            })
        }

        function onFindTextResult(activeMatchIndex, matchCount) {
            root.findTextFinished({
                numberOfMatches: matchCount,
                activeMatch: matchCount > 0 ? activeMatchIndex + 1 : 0
            })
        }

        function onHistoryItemsChanged() { root.rebuildHistoryModel() }
        function onCurrentHistoryIndexChanged() { root.rebuildHistoryModel() }
    }

    function rebuildHistoryModel() {
        historyModel.clear()
        const items = backend.historyItems
        const currentIdx = backend.currentHistoryIndex
        for (let i = 0; i < items.length; ++i) {
            const entry = items[i]
            historyModel.append({
                title: entry.title ?? "",
                icon: "",
                offset: i - currentIdx
            })
        }
    }

    function loadUrl(newUrl) {
        backend.loadUrl(newUrl)
    }

    function goBack() {
        backend.goBack()
    }

    function goForward() {
        backend.goForward()
    }

    function goBackOrForward(offset) {
        backend.goBackOrForward(offset)
    }

    function reload() {
        if (backend.url.toString() !== "") {
            backend.loadUrl(backend.url)
        }
    }

    function stop() {
        backend.stop()
    }

    function findText(text, flags) {
        if (!text) {
            backend.stopFind()
            return
        }

        const findFlags = flags === undefined ? 0 : flags
        backend.findText(text, findFlags)
    }

    function showFindPanel() {
        backend.showFindPanel()
    }

    function hideFindPanel() {
        backend.hideFindPanel()
    }

    function changeZoomFactor(factor) {
        backend.zoomFactor = factor
    }

    function acceptAsNewWindow(request) {
        console.warn("WebViewAdapter: acceptAsNewWindow not supported")
    }

    function detachView() {
    }

    function triggerWebAction(action) {
        switch (action) {
            case AbstractWebView.WebAction.Back:
                goBack()
                break
            case AbstractWebView.WebAction.Forward:
                goForward()
                break
            case AbstractWebView.WebAction.Stop:
                stop()
                break
            case AbstractWebView.WebAction.Reload:
                reload()
                break
            case AbstractWebView.WebAction.Cut:
                backend.runJavaScript("document.execCommand('cut')")
                break
            case AbstractWebView.WebAction.Copy:
                backend.runJavaScript("document.execCommand('copy')")
                break
            case AbstractWebView.WebAction.Paste:
                backend.runJavaScript("document.execCommand('paste')")
                break
            case AbstractWebView.WebAction.Undo:
                backend.runJavaScript("document.execCommand('undo')")
                break
            case AbstractWebView.WebAction.Redo:
                backend.runJavaScript("document.execCommand('redo')")
                break
            case AbstractWebView.WebAction.SelectAll:
                backend.runJavaScript("document.execCommand('selectAll')")
                break
            case AbstractWebView.WebAction.PasteAndMatchStyle:
                backend.runJavaScript("document.execCommand('paste')")
                break
            case AbstractWebView.WebAction.RequestClose:
                root.windowCloseRequested()
                break
            default:
                console.warn("WebViewAdapter: Web action not supported:", action)
        }
    }
}
