import QtQuick

import StatusQ

import utils

import AppLayouts.Browser.adapters
import AppLayouts.Browser.stores as BrowserStores

/**
 * Orchestrates Download Requests and list/pill actions (ADR 0006 / issue 05).
 * Retry is a host-side re-issue via Backend downloadUrl on a matching profile —
 * not library retry() (live object is usually already gone). The next matching
 * downloadRequested reattaches onto the same Record (no duplicate History row).
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

    // Record waiting for the Retry downloadRequested; cleared on match or superseded.
    property var pendingRetryRecord: null

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

    /// hostView is the host Web View (LazyWebViewAdapter) that raised the request.
    /// Prefer it over Backend download.view (missing on mobile; wrong identity on desktop).
    function handleDownloadRequest(download, hostView) {
        if (!download)
            return

        let record = null
        const pending = root.pendingRetryRecord
        if (pending && root._urlsMatch(pending.url, download.url)
                && downloadsStore.reattachForRetry) {
            root.pendingRetryRecord = null
            record = downloadsStore.reattachForRetry(pending, download, hostView)
        } else {
            record = downloadsStore.addDownload(download, hostView)
        }
        downloadsStore.acceptLiveDownload(download, record)

        // New download dismisses Find and shows the strip (Find XOR).
        if (root.findUiActive)
            hideFindUiFn()
        root.findUiActive = false
        setFooterVisibleFn(true)

        // Download-only Tab (target=_blank attachment): leave the strip via removeView,
        // which retains the Web View on mobile while Downloads are non-terminal.
        const view = hostView || (record ? record.originatingView : null) || download.view
        if (!view)
            return

        const count = getTabsCountFn()
        for (var i = 0; i < count; ++i) {
            var tab = getWebViewFn(i)
            if (tab === view && !tab.htmlPageLoaded && tab.title === "") {
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

        if (downloadComplete)
            openCompletedRecord(record)
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
            openCompletedRecord(record)
            downloadsStore.dismissRecordFromStrip(record)
            if (downloadsStore.downloadStripModel.length === 0)
                setFooterVisibleFn(false)
        }
    }

    /// Prefer our browser when the type is renderable; otherwise hand off to the OS.
    /// Missing File blocks both routes (ADR 0006 §8 / polish 05).
    function openCompletedRecord(record) {
        if (!record)
            return false
        if (openInBrowserRecord(record))
            return true
        if (record.missingFile)
            return false
        downloadsStore.openRecord(record)
        return true
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

        // Navigating to local audio/video makes WebEngine download it again instead of
        // playing it — open a player page for those. No page, no in-browser route.
        if (downloadsStore.isPlayableMedia(record)) {
            const page = downloadsStore.mediaPlayerPageUrl(record)
            if (!page)
                return false
            openUrlFn(page)
            return true
        }

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
        root.pendingRetryRecord = record
        webView.downloadUrl(url, record.fileName || "")
        return true
    }

    function _urlsMatch(a, b) {
        const left = String(a || "")
        const right = String(b || "")
        return left.length > 0 && left === right
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

    /// Retry Backend must match the Record profile (ADR 0006 §7) and must be a
    /// live Tab Web View — never a Retained View (ADR 0006 §6).
    function _webViewForRetry(record) {
        const count = getTabsCountFn ? getTabsCountFn() : 0
        const wantOtr = !!record.offTheRecord
        for (let i = 0; i < count; ++i) {
            const tab = getWebViewFn(i)
            if (!tab || !tab.downloadUrl)
                continue
            if (tab.retained)
                continue
            const otr = tab.offTheRecord !== undefined ? !!tab.offTheRecord
                        : (tab.profileParams ? !!tab.profileParams.offTheRecord : false)
            if (otr === wantOtr)
                return tab
        }
        return null
    }
}
