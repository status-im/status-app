import QtQuick

import QtModelsToolkit

import StatusQ
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Browser.adapters
import AppLayouts.Browser.stores as BrowserStores

/**
 * Orchestrates Download Requests and list/pill actions (ADR 0006).
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

    // Mobile Find XOR strip: actively closes the Find UI when a new Download
    // starts. Closing Find is an action on the Find UI, not derivable state.
    property var hideFindUiFn: function() {}

    /// Find XOR Download Pill strip (mobile).
    /// The one derived view of strip visibility: session pills exist, Find is
    /// closed, and the user has not dismissed the strip. BrowserLayout binds
    /// its footer/strip to this — nothing writes visibility imperatively.
    readonly property bool stripVisible: stripPresenter.stripVisible

    // Presenter over the three inputs. findOpen / userDismissed change only
    // via setFindOpen, dismissStrip and handleDownloadRequest; model emptiness
    // is observed from the store.
    readonly property QtObject _stripPresenter: QtObject {
        id: stripPresenter

        property bool findOpen: false
        property bool userDismissed: false

        // A JS array today, possibly a QML model later: count for models,
        // length for arrays. Both re-evaluate on change.
        readonly property int pillCount: {
            const model = root.downloadsStore?.downloadStripModel
            return model?.ModelCount?.count ?? model?.length ?? 0
        }

        readonly property bool stripVisible: !findOpen && !userDismissed
            && pillCount > 0
    }

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

    /// Opens a local file through the Web View's loadFileUrl (read grant for a
    /// directory); empty readAccessUrl means the file's own directory.
    property var openFileUrlFn: function(fileUrl, readAccessUrl) {
        console.warn("BrowserDownloadsContext: openFileUrlFn not set")
    }

    // Backend PDF-rendering Capability. BrowserLayout overrides with
    // BrowserBackendCapabilities.pdfViewerSupported; tests inject their own.
    property var supportsPdfFn: function() { return false }

    /// The open-a-downloaded-file seam (ADR 0006 §8): format allowlist, player
    /// pages, local-URL guard exception. Internal composition — BrowserLayout
    /// talks to this context only; the seam sees narrow injected functions,
    /// never the store.
    readonly property BrowserDownloadOpenContext _openContext: BrowserDownloadOpenContext {
        openUrlFn: (url) => root.openUrlFn(url)
        openFileUrlFn: (fileUrl, readAccessUrl) => root.openFileUrlFn(fileUrl, readAccessUrl)
    }

    /// Find UI open/close hook (mobile call sites). Opening Find hides the
    /// strip; closing Find restores it only when session pills remain and the
    /// user did not dismiss the strip (all derived — see stripVisible).
    function setFindOpen(open) {
        stripPresenter.findOpen = !!open
    }

    /// Strip close button: hidden until the next download starts.
    function dismissStrip() {
        stripPresenter.userDismissed = true
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
                && typeof downloadsStore.reattachForRetry === "function") {
            record = downloadsStore.reattachForRetry(pending, download, hostView)
            // Reattach declined: track as new rather than accept untracked —
            // a duplicate History row beats a lost Download.
            if (!record)
                record = downloadsStore.addDownload(download, hostView)
        } else {
            record = downloadsStore.addDownload(download, hostView)
        }
        downloadsStore.acceptLiveDownload(download, record)

        // New download dismisses Find and re-shows the strip (Find XOR),
        // expressed as presenter input changes; hideFindUiFn additionally
        // closes the actual Find UI (not derivable from state).
        if (stripPresenter.findOpen)
            hideFindUiFn()
        stripPresenter.findOpen = false
        stripPresenter.userDismissed = false

        // Download-only Tab (target=_blank attachment): leave the strip via removeView,
        // which retains the Web View on mobile while Downloads are non-terminal.
        const view = hostView || (record ? record.originatingView : null) || download.view
        if (!view)
            return

        const count = getTabsCountFn()
        for (var i = 0; i < count; ++i) {
            var tab = getWebViewFn(i)
            // Only a Tab a page opened that never committed a page of its own —
            // marked at creation, never guessed from title or load state.
            if (tab === view && tab.pristinePopup) {
                removeViewFn(i)
                break
            }
        }
    }

    /// true if the file opened (caller closes the overview). false on retry.
    function openDownloadFromList(record) {
        if (!record)
            return false

        if (downloadsStore.canRetryFromTap(record)) {
            retryRecord(record)
            return false
        }

        if (record.state === AbstractWebView.DownloadState.DownloadCompleted)
            return openCompletedRecord(record)
        return false
    }

    function handlePillClicked(record) {
        if (!record)
            return

        if (downloadsStore.canRetryFromTap(record)) {
            retryRecord(record)
            return
        }

        if (record.state === AbstractWebView.DownloadState.DownloadCompleted) {
            openCompletedRecord(record)
            // Dropping the last pill empties the strip model — stripVisible
            // observes emptiness, so the strip hides by derivation.
            downloadsStore.dismissRecordFromStrip(record)
        }
    }

    /// Prefer our browser when the type is renderable; otherwise hand off to the OS.
    /// Missing File blocks both routes (ADR 0006 §8).
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

    // Missing File markers go stale while the app is backgrounded (files can
    // be removed externally); refresh when it returns to the foreground.
    readonly property Connections _appActiveRefresh: Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive)
                root.refreshMissingFiles()
        }
    }

    /// The one capability vocabulary for a Download Record menu:
    /// store predicates + the open seam's canOpenInBrowser + the platform
    /// share-vs-copy fact. BIND it at the call site
    /// (capabilities: ctx.capabilitiesFor(menu.record, options)) so a stale
    /// menu is structurally impossible — the Missing File refresh happens here,
    /// never at call sites. options.showDismiss — pill strip session dismiss.
    /// options.showDownloadsEntry — pill strip "Downloads" entry;
    /// list menus never pass it — the user is already in the Downloads List.
    function capabilitiesFor(record, options) {
        downloadsStore.refreshMissingFiles()
        return {
            openInBrowser: _openContext.canOpenInBrowser(record, supportsPdfFn()),
            shareFile: downloadsStore.canShareFile(record),
            shareUrl: downloadsStore.canShareUrl(record),
            showInFolder: downloadsStore.canShowInFolder(record),
            retry: downloadsStore.canRetryFromMenu(record),
            dismiss: !!(options && options.showDismiss),
            downloadsEntry: !!(options && options.showDownloadsEntry),
            useShareLabels: !!(downloadsStore.platform && downloadsStore.platform.preferShareSheet)
        }
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
