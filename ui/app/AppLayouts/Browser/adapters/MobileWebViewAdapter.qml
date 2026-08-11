import QtQuick

import StatusQ.CustomWebView 1.0

AbstractWebView {
    id: root

    property alias url: backend.url
    readonly property alias loading: backend.loading
    readonly property alias title: backend.title
    readonly property alias canGoBack: backend.canGoBack
    readonly property alias canGoForward: backend.canGoForward
    readonly property alias loadProgress: backend.loadProgress
    readonly property alias htmlPageLoaded: backend.loaded
    readonly property alias zoomFactor: backend.zoomFactor

    ListModel {
        id: historyModel
    }

    readonly property var history: ({ items: historyModel })
    readonly property url icon: backend.favicon

    supportsZoom: true
    supportsDevTools: false
    supportsFindInPage: backend.findSupported
    supportsIncognito: true
    supportsHistory: true
    hasNativeFindPanel: backend.hasNativeFindPanel
    clearSiteDataSupported: backend.clearSiteDataSupported
    clearing: backend.clearing

    MobileWebViewBackend {
        id: backend
        anchors.fill: parent
        visible: root.visible
        freeze: root.freeze
        userScripts: root.profileParams.scripts
        webChannel: root.webChannel

        offTheRecord: root.profileParams.offTheRecord
        storageName: root.profileParams.storageName
        httpUserAgent: root.profileParams.userAgent
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

        // clearSiteData reloads natively (cache-bypass); clearProfileData does not.
        function onClearProfileDataCompleted() { backend.reload() }

        function onDownloadRequested(download, token) {
            root.downloadRequested(download, token || "")
        }

        function onLinkLongPressed(linkUrl, imageUrl, position) {
            root.linkLongPressed(linkUrl, imageUrl, position)
        }
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

    /// A plain load hands WebKit one file; subresources need the grant (§8).
    function loadFileUrl(fileUrl, readAccessUrl) {
        backend.loadFileUrl(fileUrl, readAccessUrl || "")
    }

    /// Host-side Retry (ADR 0006): re-issue via Backend downloadUrl on this profile.
    function downloadUrl(url, suggestedFileName, token) {
        if (backend.downloadUrl)
            backend.downloadUrl(url, suggestedFileName || "", token || "")
        else
            console.warn("MobileWebViewAdapter: backend.downloadUrl unavailable")
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
        backend.reload()
    }

    function stop() {
        backend.stop()
    }

    function forceReload() {
        backend.reloadAndBypassCache()
    }

    // Full native per-site wipe (cookies + cache + storage + SW); backend
    // reloads with cache-bypass on completion (mobilewebview ADR 0004).
    function clearSiteData() {
        backend.clearSiteData()
    }

    // Profile-wide "clear browsing data": HTTP cache + cookies + DOM storage.
    // Reloads the current view once clearProfileDataCompleted fires.
    function clearBrowsingData() {
        backend.clearProfileData()
    }

    function runJavaScript(script, callback) {
        // Mobile backend has no result callback; fire-and-forget.
        // Do not invent a completion value — callers must not rely on callback.
        backend.runJavaScript(script)
        void callback
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

    // targetSize is the logical on-screen size
    function grabToImage(callback, targetSize) {
        function onReady(imageUrl, ok) {
            backend.snapshotReady.disconnect(onReady)
            if (callback)
                callback({ url: ok ? imageUrl : "" })
        }
        backend.snapshotReady.connect(onReady)

        const scale = 2;
        if (targetSize !== undefined && targetSize !== null) {
            backend.requestSnapshot(
                Qt.size(
                    targetSize.width * scale,
                    targetSize.height * scale
                )
            )
        } else
            backend.requestSnapshot()
    }

    function acceptAsNewWindow(request) {
        console.warn("WebViewAdapter: acceptAsNewWindow not supported")
    }

    // hide the native backend so the UIKit WKWebView is removed before destroy.
    function detachView() {
        backend.webChannel = null
        backend.stop()
        backend.visible = false
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
