import QtQuick

import StatusQ
import StatusQ.Core.Utils as SQUtils

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

    // One-shot Record armed by retryRecord for the reattach; consumed (or dropped)
    // by the next downloadRequested and expired by timer so a failed retry can
    // never capture a later unrelated download of the same URL.
    property var _pendingRetry: null

    readonly property Timer _pendingRetryExpiry: Timer {
        interval: 10000
        onTriggered: root._pendingRetry = null
    }

    property var openUrlFn: function(url) {
        console.warn("BrowserDownloadsContext: openUrlFn not set")
    }

    // Backend PDF-rendering Capability. BrowserLayout always overrides with the
    // current Web View's supportsPdfViewer; the trivial default only keeps the
    // type instantiable on its own (tests inject their own).
    property var supportsPdfFn: function() { return false }

    /// The open-a-downloaded-file seam (ADR 0006 §8): format allowlist, player
    /// pages, local-URL guard exception. Internal composition — BrowserLayout
    /// talks to this context only; the seam sees narrow injected functions,
    /// never the store.
    readonly property BrowserDownloadOpenContext _openContext: BrowserDownloadOpenContext {
        isKnownTargetPathFn: (path) => root.downloadsStore.isKnownTargetPath(path)
        openUrlFn: (url) => root.openUrlFn(url)
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

        // One-shot: whatever this request is, the retry arm does not outlive it.
        const pending = root._pendingRetry
        root._pendingRetry = null
        root._pendingRetryExpiry.stop()

        let record = null
        if (pending && root._urlsMatch(pending.url, download.url)
                && downloadsStore.reattachForRetry) {
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

    /// true if the file opened (caller closes the overview). false on retry.
    function openDownloadFromList(downloadComplete, index) {
        const record = downloadsStore.getDownload(index)
        if (!record)
            return false

        if (downloadsStore.canRetryFromTap(record)) {
            retryRecord(record)
            return false
        }

        if (downloadComplete)
            return openCompletedRecord(record)
        return false
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
        // iOS: openUrlExternally ignores file:// — use the share sheet.
        if (SQUtils.Utils.isIOS)
            return shareFileRecord(record)
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
        return _openContext.openInBrowser(record, supportsPdfFn())
    }

    /// Local-URL guard exception for the Backend's local-browsing guard
    /// (WebViewAdapter, wired via BrowserWebViewContext).
    function isBrowsableLocalUrl(url) {
        return _openContext.isBrowsableLocalUrl(url)
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
        root._pendingRetry = record
        root._pendingRetryExpiry.restart()
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
        menu.canOpenInBrowser = _openContext.canOpenInBrowser(record, pdf)
        menu.canShowInFolder = downloadsStore.canShowInFolder(record)
        menu.canRetry = downloadsStore.canRetryFromMenu(record)
        menu.showDismiss = !!(options && options.showDismiss)
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
