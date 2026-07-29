import QtQuick

import StatusQ

import utils

import AppLayouts.Browser.adapters
import AppLayouts.Browser.stores as BrowserStores

/**
 * Orchestrates Download Requests and list/pill actions (ADR 0006 / issue 05).
 * Retry is a host-side re-issue via Backend downloadUrl on a matching profile —
 * not library retry() (live object is usually already gone).
 */
QtObject {
    id: root

    required property BrowserStores.DownloadsStore downloadsStore
    required property var getWebViewFn
    required property var getTabsCountFn
    required property var removeViewFn
    required property var setFooterVisibleFn

    // Mobile Find XOR strip: hide Find UI when a new Download starts.
    property var hideFindUiFn: function() {}

    // True while Find in page (QML bar or native panel) is open on mobile.
    property bool findUiActive: false

    property var openUrlFn: function(url) {
        console.warn("BrowserDownloadsContext: openUrlFn not set")
    }

    property var supportsPdfFn: function() {
        const webView = root._firstWebView()
        if (webView && webView.supportsPdfViewer !== undefined)
            return !!webView.supportsPdfViewer
        return false
    }

    /// Find XOR Download Pill strip (browser-downloads-ux 05, mobile).
    /// Opening Find hides the strip; closing Find restores only if we hid it
    /// for Find and session pills remain. Does not re-show a user-dismissed strip.
    function setFindUiActive(active) {
        const wasActive = root.findUiActive
        root.findUiActive = !!active
        if (root.findUiActive) {
            setFooterVisibleFn(false)
            return
        }
        if (wasActive && downloadsStore.downloadStripModel.length > 0)
            setFooterVisibleFn(true)
    }

    /// Hide the strip when empty or Find is open; never force-show (user may have closed it).
    function syncStripVisibility() {
        if (root.findUiActive || downloadsStore.downloadStripModel.length === 0)
            setFooterVisibleFn(false)
    }

    function handleDownloadRequest(download) {
        if (!download)
            return

        const record = downloadsStore.addDownload(download)
        downloadsStore.acceptLiveDownload(download, record)

        // New download dismisses Find and shows the strip (Find XOR).
        if (root.findUiActive)
            hideFindUiFn()
        root.findUiActive = false
        setFooterVisibleFn(true)

        if (!download.view)
            return

        const count = getTabsCountFn()
        for (var i = 0; i < count; ++i) {
            var tab = getWebViewFn(i)
            if (tab === download.view && !tab.htmlPageLoaded && tab.title === "") {
                removeViewFn(i)
                break
            }
        }
    }

    function openDownloadFromList(downloadComplete, index) {
        const record = downloadsStore.getDownload(index)
        if (!record)
            return

        if (downloadsStore.canRetryFromTap(record)) {
            retryRecord(record)
            return
        }

        if (downloadComplete) {
            downloadsStore.refreshMissingFiles()
            if (record.missingFile)
                return
            downloadsStore.openFile(index)
        }
    }

    function handlePillClicked(index) {
        const record = downloadsStore.getStripDownload(index)
        if (!record)
            return

        if (downloadsStore.canRetryFromTap(record)) {
            retryRecord(record)
            return
        }

        if (record.state === AbstractWebView.DownloadState.DownloadCompleted) {
            if (!record.missingFile)
                downloadsStore.openRecord(record)
            downloadsStore.dismissRecordFromStrip(record)
            if (downloadsStore.downloadStripModel.length === 0)
                setFooterVisibleFn(false)
        }
    }

    function shareFileRecord(record) {
        downloadsStore.refreshMissingFiles()
        return downloadsStore.shareFile(record)
    }

    function shareUrlRecord(record) {
        return downloadsStore.shareUrl(record)
    }

    function openInBrowserRecord(record) {
        downloadsStore.refreshMissingFiles()
        if (!downloadsStore.canOpenInBrowser(record, supportsPdfFn()))
            return false
        const path = record.targetPath
        if (!path)
            return false
        openUrlFn(UrlUtils.urlFromUserInput(path))
        return true
    }

    function retryRecord(record) {
        if (!downloadsStore.canRetryFromMenu(record) && !downloadsStore.canRetryFromTap(record))
            return false
        const url = downloadsStore.sourceUrlString(record)
        if (!url)
            return false

        const webView = root._webViewForRetry(record)
        if (!webView || !webView.downloadUrl) {
            console.warn("BrowserDownloadsContext: no Backend available for retry")
            return false
        }
        webView.downloadUrl(url, record.fileName || "")
        return true
    }

    function refreshMissingFiles() {
        downloadsStore.refreshMissingFiles()
    }

    /// Fill a Record menu's record + capability flags (menus stay store-free).
    /// options.showDismiss — pill strip session dismiss.
    function populateRecordMenu(menu, record, index, options) {
        if (!menu || !record)
            return
        downloadsStore.refreshMissingFiles()
        const pdf = supportsPdfFn()
        menu.record = record
        menu.index = index
        menu.useShareLabels = !!downloadsStore.preferShareSheet
        menu.canShareFile = downloadsStore.canShareFile(record)
        menu.canShareUrl = downloadsStore.canShareUrl(record)
        menu.canOpenInBrowser = downloadsStore.canOpenInBrowser(record, pdf)
        menu.canShowInFolder = downloadsStore.canShowInFolder(record)
        menu.canRetry = downloadsStore.canRetryFromMenu(record)
        menu.showDismiss = !!(options && options.showDismiss)
    }

    function _firstWebView() {
        const count = getTabsCountFn ? getTabsCountFn() : 0
        for (let i = 0; i < count; ++i) {
            const tab = getWebViewFn(i)
            if (tab)
                return tab
        }
        return null
    }

    function _webViewForRetry(record) {
        const count = getTabsCountFn ? getTabsCountFn() : 0
        const wantOtr = !!record.offTheRecord
        let fallback = null
        for (let i = 0; i < count; ++i) {
            const tab = getWebViewFn(i)
            if (!tab || !tab.downloadUrl)
                continue
            if (fallback === null)
                fallback = tab
            const otr = tab.offTheRecord !== undefined ? !!tab.offTheRecord
                        : (tab.profileParams ? !!tab.profileParams.offTheRecord : false)
            if (otr === wantOtr)
                return tab
        }
        return fallback
    }
}
