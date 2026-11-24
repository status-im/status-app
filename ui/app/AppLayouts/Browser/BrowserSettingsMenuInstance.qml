import AppLayouts.Browser.popups
import AppLayouts.Browser.webview

BrowserSettingsMenu {
    id: root

    required property BrowserWebViewContext webViewContext

    incognitoMode: root.webViewContext.currentWebView?.incognito ?? false
    zoomFactor: root.webViewContext.currentWebView?.zoomFactor ?? 1
    clearingBrowsingData: root.webViewContext.currentWebView?.clearing ?? false
    clearSiteDataSupported: root.webViewContext.currentWebView?.clearSiteDataSupported ?? true

    onForceReload: root.webViewContext.forceReloadCurrent()
    onClearSiteData: root.webViewContext.clearSiteDataCurrent()
    onZoomIn: root.webViewContext.changeZoomCurrent(0.1)
    onZoomOut: root.webViewContext.changeZoomCurrent(-0.1)
    onResetZoomFactor: root.webViewContext.resetZoomCurrent()
}
