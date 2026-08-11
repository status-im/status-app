import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core.Utils as SQUtils

import utils

import AppLayouts.Browser.adapters
import AppLayouts.Browser.provider.qml

import "../provider/qml/Utils.js" as BrowserProviderUtils

QtObject {
    id: root

    required property bool thirdpartyServicesEnabled
    required property bool isDebugEnabled
    required property bool isMobile
    required property bool hasPopups

    required property var browserSettings
    required property var connectorController
    required property bool dappsEnabled

    required property Item hostStackLayout
    required property var tabsModel
    required property ProfileParams defaultProfileParams
    required property ProfileParams otrProfileParams

    required property var bookmarksStore
    required property var downloadsStore

    readonly property var profileManager: _profileManagerLoader.item

    readonly property Loader _profileManagerLoader: Loader {
        active: !root.isMobile
        source: "../adapters/ProfileManager.qml"
    }

    readonly property Connections _viewlessDownloads: Connections {
        target: root.profileManager
        ignoreUnknownSignals: true
        function onViewlessDownloadRequested(download, token) {
            root.downloadRequestHandler(download, null, token)
        }
    }

    required property var determineRealURLFn
    /// (download, hostView, token) — hostView is the LazyWebViewAdapter that raised
    /// the request, null for a host-side re-issue that no Tab initiated. token is
    /// the correlation token echoed by the Backend (empty unless the host re-issued).
    required property var downloadRequestHandler
    /// (linkUrl, imageUrl, position, hostView) — long-press menu (mobile Backends).
    required property var linkLongPressHandler
    required property var sslErrorHandler
    required property var jsDialogHandler
    required property var findTextFinishedHandler
    required property var savedSessionContext

    enum ContentMode {
        WebContent = 0,
        EmptyContent
    }

    // Retained Views: host Web Views kept alive (hidden + frozen) after Tab close
    // while they still own non-terminal Downloads. Not part of the Tab set.
    property var _retainedViews: []

    readonly property Item currentWebView: tabsModel.currentIndex < tabsModel.count ? (getCurrentWebView() ?? null) : null
    readonly property int currentContentMode: {
        if (!currentWebView)
            return BrowserWebViewContext.ContentMode.EmptyContent
        if (!currentWebView.url?.toString())
            return BrowserWebViewContext.ContentMode.EmptyContent
        return BrowserWebViewContext.ContentMode.WebContent
    }

    readonly property string currentClientId: currentWebView?.bridge?.clientId
                                              ?? ConnectorConstants.clientIdFor(currentWebView ? currentWebView.offTheRecord : false)

    readonly property Connections _currentIndexConnections: Connections {
        target: tabsModel
        function onCurrentIndexChanged() {
            root.ensureCurrentWebViewLoaded()
        }
    }

    function createEmptyTab(profileParams, createAsStartPage = false, focusOnNewTab = true, url = undefined, initialTitle = undefined, initialIcon = undefined, initialUid = undefined) {
        focusOnNewTab = focusOnNewTab && !createAsStartPage

        var webview = webViewAdapterComponent.createObject(hostStackLayout, {
            profileParams: profileParams
        })
        if (!webview) {
            console.error("[Browser] Failed to create webview")
            return null
        }

        webview.uid = (initialUid || "").trim() || SQUtils.Utils.uuid()

        savedSessionContext.seedWebView(webview, { title: initialTitle, icon: initialIcon })

        tabsModel.createEmptyTab(createAsStartPage, focusOnNewTab)

        if (createAsStartPage && thirdpartyServicesEnabled)
            webview.url = Constants.browserDefaultHomepage
        else if (url !== undefined)
            webview.url = url
        else if (!!browserSettings.browserHomepage)
            webview.url = determineRealURLFn(browserSettings.browserHomepage)

        if ((focusOnNewTab || createAsStartPage) && webview.url.toString() && typeof webview.ensureLoaded === "function")
            webview.ensureLoaded()

        return webview
    }

    function getCurrentWebView() { // -> WebEngineView/WebView
        return getWebView(tabsModel.currentIndex)
    }

    function getWebView(index) { // -> WebEngineView/WebView
        return hostStackLayout.children[index]
    }

    function ensureCurrentWebViewLoaded() {
        const w = getCurrentWebView()
        if (w && w.url && w.url.toString() && typeof w.ensureLoaded === "function")
            w.ensureLoaded()
    }

    function setCurrentWebUrl(url) {
        var target = currentWebView
        if (!target) {
            console.error("[Browser] currentWebView is null, cannot set URL")
            return
        }

        const newUrl = determineRealURLFn(url)
        Qt.callLater(function() {
            target.url = newUrl
            if (newUrl && newUrl.toString() && typeof target.ensureLoaded === "function")
                target.ensureLoaded()
        })
    }

    function disconnectDapp(dappUrl) {
        const origin = BrowserProviderUtils.normalizeOrigin(dappUrl)
        if (!origin || !connectorController)
            return false

        return connectorController.disconnect(origin, currentClientId)
    }

    function changeAccountForCurrentDapp(address) {
        currentWebView?.bridge?.connectorManager.changeAccount(address)
    }

    function goBackCurrent() {
        if (!currentWebView)
            return
        currentWebView.goBack()
    }

    function goForwardCurrent() {
        if (!currentWebView)
            return
        currentWebView.goForward()
    }

    function goBackOrForwardCurrent(offset) {
        if (!currentWebView)
            return
        currentWebView.goBackOrForward(offset)
    }

    function reloadCurrent() {
        if (!currentWebView)
            return
        if (typeof currentWebView.ensureLoaded === "function")
            currentWebView.ensureLoaded()
        currentWebView.reload()
    }

    function stopCurrent() {
        if (!currentWebView)
            return
        currentWebView.stop()
    }

    function forceReloadCurrent() {
        if (!currentWebView)
            return
        if (typeof currentWebView.ensureLoaded === "function")
            currentWebView.ensureLoaded()
        currentWebView.forceReload()
    }

    function clearSiteDataCurrent() {
        if (!currentWebView)
            return
        currentWebView.clearSiteData()
    }

    function clearBrowsingDataCurrent() {
        if (!currentWebView)
            return
        currentWebView.clearBrowsingData()
    }

    function findTextCurrent(text, backward = false) {
        if (!currentWebView)
            return

        if (backward) {
            currentWebView.findText(text, currentWebView.findBackward)
            return
        }

        currentWebView.findText(text)
    }

    function setIncognitoCurrent(checked) {
        if (!currentWebView)
            return
        const target = checked ? otrProfileParams : defaultProfileParams
        if (currentWebView.profileParams !== target)
            currentWebView.profileParams = target
    }

    // Stop → update setting → deferred reload so profile.httpUserAgent Binding
    // settles before navigation.
    function setCompatibilityMode(checked) {
        for (let i = 0; i < tabsModel.count; ++i)
            getWebView(i)?.stop()

        browserSettings.compatibilityMode = checked

        Qt.callLater(() => {
            for (let i = 0; i < tabsModel.count; ++i)
                getWebView(i)?.reload()
        })
    }

    function changeZoomCurrent(delta) {
        if (!currentWebView)
            return
        currentWebView.changeZoomFactor(currentWebView.zoomFactor + delta)
    }

    function resetZoomCurrent() {
        if (!currentWebView)
            return
        currentWebView.changeZoomFactor(1.0)
    }

    function removeView(index) {
        if (index < 0 || index >= tabsModel.count)
            return

        var view = getWebView(index)
        if (tabsModel.count <= 1) {
            var fallbackProfileParams = root.currentWebView ? currentWebView.profileParams : root.defaultProfileParams
            createEmptyTab(fallbackProfileParams, true)
        }
        tabsModel.removeTab(index)
        if (!view)
            return

        // Mobile Backend aborts Downloads when the Web View is destroyed.
        // Retain (hide + freeze) until DownloadsStore reports the view is clear.
        // Desktop WebEngine keeps transfers alive after view destruction — no retain.
        // Closing never cancels a Download (ADR 0006 §6).
        const shouldRetain = root.isMobile
            && !!downloadsStore
            && typeof downloadsStore.viewHasNonTerminalDownloads === "function"
            && downloadsStore.viewHasNonTerminalDownloads(view)

        if (shouldRetain) {
            view.retained = true
            view.focus = false
            // Reparent out of the StackLayout so children stay 1:1 with tabs.
            // visible/freeze follow `retained` bindings on the adapter.
            // Do not detachView()/stop() — that would abort the transfer.
            view.parent = null
            _retainedViews = _retainedViews.concat([view])
            return
        }

        root._destroyWebView(view)
    }

    /// Close the Tab backing `view`, whatever index it sits at. The host names
    /// the Web View it got from a signal; the Tab set is ours, so the lookup is
    /// too — no index arithmetic escapes this object.
    function removeViewFor(view) {
        if (!view)
            return false
        for (let i = 0; i < tabsModel.count; ++i) {
            if (getWebView(i) === view) {
                removeView(i)
                return true
            }
        }
        return false
    }

    /// A live Tab whose Backend can run a host-side Download re-issue on the
    /// requested profile (ADR 0006 §7), or null when there is none.
    /// Retained Views finish only what they already own (§6), and a local
    /// preview is not a browsing profile at all — re-issuing on either would
    /// break the mandatory profile match.
    function firstLiveDownloadBackend(wantOtr) {
        for (let i = 0; i < tabsModel.count; ++i) {
            const view = getWebView(i)
            if (!view || typeof view.downloadUrl !== "function")
                continue
            if (view.retained || view.profileParams?.localPreview)
                continue
            if (!!view.offTheRecord !== !!wantOtr)
                continue
            return view
        }
        return null
    }

    function _destroyWebView(view) {
        if (!view)
            return
        view.visible = false
        view.enabled = false
        view.focus = false
        if (typeof view.detachView === "function")
            view.detachView()
        view.parent = null
        view.destroy()
    }

    function _destroyRetainedView(view) {
        if (!view)
            return
        const next = []
        let found = false
        for (let i = 0; i < _retainedViews.length; ++i) {
            if (_retainedViews[i] === view)
                found = true
            else
                next.push(_retainedViews[i])
        }
        if (!found)
            return
        _retainedViews = next
        root._destroyWebView(view)
    }

    readonly property Connections _retainedDownloadsConnections: Connections {
        target: root.downloadsStore
        ignoreUnknownSignals: true
        function onViewDownloadsCleared(view) {
            root._destroyRetainedView(view)
        }
    }

    readonly property var webViewAdapterComponent: Component {
        LazyWebViewAdapter {
            id: lazyView

            // StackLayout never sizes a child that was added while the layout was
            // hidden, and neither forceLayout() nor re-setting currentIndex repairs
            // it — the view stays 0x0 and renders nothing (issue 21282). Size to the
            // host instead of relying on the layout to do it.
            width: root.hostStackLayout.width
            height: root.hostStackLayout.height

            // On mobile, only the active tab must be visible; native WKWebView
            // subviews share the same UIKit window and ignore QML z-order,
            // so StackLayout alone cannot hide inactive tabs reliably.
            // Retained Views stay hidden regardless of StackLayout current item.
            visible: retained ? false
                     : (root.isMobile ? StackLayout.isCurrentItem : true)
            enabled: visible
            // Freeze while a QML popup is shown, or while Retained for Downloads.
            freeze: root.isMobile && (root.hasPopups || retained)

            readonly property ConnectorBridge bridge: ConnectorBridge {
                connectorController: root.dappsEnabled ? root.connectorController : null
                tabUrl: lazyView.url
                tabIncognito: lazyView.offTheRecord
                tabTitle: lazyView.title
                tabIconUrl: lazyView.icon
            }

            webChannel: bridge.channel

            bookmarksStore: root.bookmarksStore
            profileManager: root.profileManager
            enableJsLogs: root.isDebugEnabled
            localAccountSensitiveSettings: root.browserSettings

            devToolsEnabled: root.browserSettings.devToolsEnabled
            onDevToolsToggled: enabled => root.browserSettings.devToolsEnabled = enabled

            onWindowCloseRequested: root.removeView(StackLayout.index)
            onNewWindowRequested: (makeCurrent, requestedUrl, callback) => {
                var profileParams = root.currentWebView ? root.currentWebView.profileParams : root.defaultProfileParams
                var tab = root.createEmptyTab(profileParams, false, makeCurrent, requestedUrl)
                // Born from a page, nothing loaded in it yet: the Tab is download-only
                // until it commits a page of its own (ADR 0006 §6).
                if (tab)
                    tab.pristinePopup = true
                callback(tab)
            }
            onDownloadRequested: (download, token) => {
                // Retained Views finish only the Downloads they already own (ADR 0006 §6).
                if (lazyView.retained) {
                    if (download && download.cancel)
                        download.cancel()
                    return
                }
                root.downloadRequestHandler(download, lazyView, token)
            }
            onLinkLongPressed: (linkUrl, imageUrl, position) => {
                if (!lazyView.retained)
                    root.linkLongPressHandler(linkUrl, imageUrl, position, lazyView)
            }
            onCertificateError: (error) => root.sslErrorHandler(error)
            onJavaScriptDialogRequested: (request) => root.jsDialogHandler(request)
            onFindTextFinished: (result) => root.findTextFinishedHandler(result)
        }
    }
}
