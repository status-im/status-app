import AppLayouts.Browser.popups
import AppLayouts.Browser.webview

MobileSettingsMenu {
    id: root

    required property BrowserWebViewContext webViewContext

    supportsIncognito: root.webViewContext.currentWebView?.supportsIncognito ?? false
    incognitoMode: root.webViewContext.currentWebView?.incognito ?? false
    supportsZoom: root.webViewContext.currentWebView?.supportsZoom ?? false
    zoomFactor: root.webViewContext.currentWebView?.zoomFactor ?? 1
    supportsFind: root.webViewContext.currentWebView?.supportsFindInPage ?? false
    clearSiteDataSupported: root.webViewContext.currentWebView?.clearSiteDataSupported ?? false
    clearing: root.webViewContext.currentWebView?.clearing ?? false

    onForceReload: root.webViewContext.forceReloadCurrent()
    onClearSiteData: root.webViewContext.clearSiteDataCurrent()
    onZoomIn: root.webViewContext.changeZoomCurrent(0.1)
    onZoomOut: root.webViewContext.changeZoomCurrent(-0.1)
    onResetZoomFactor: root.webViewContext.resetZoomCurrent()
}
