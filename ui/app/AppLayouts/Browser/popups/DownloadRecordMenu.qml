import QtQuick
import QtQuick.Controls

import StatusQ.Popups
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Browser.adapters

/**
 * One download menu for Download Pill and Downloads List.
 * Identity is the Download Record; enablement comes from one `capabilities`
 * object (BrowserDownloadsContext.capabilitiesFor) BOUND at the call site, so
 * the menu can never show stale capabilities. State-derived
 * booleans stay internal. Share vs Copy labels via capabilities.useShareLabels.
 * StatusAction has no visible; StatusMenu hides disabled items by default.
 */
StatusMenu {
    id: root

    property var record: null

    /// Pill strip opens grant session Dismiss; list opens do not.
    /// Set by openAt options; read by the host's capabilities binding.
    property bool forStrip: false

    /// The Popup this was opened from; null for pill-strip opens. Actions that
    /// navigate away from it close it, as a plain row tap does.
    // var, not Popup: the hosts are StatusQ dialogs, and a typed assignment
    // resolves Popup against the StatusQ.Popups import, throwing mid-openAt and
    // leaving the menu unopened. Only close() is ever called on it.
    property var hostPopup: null

    /// Open right-aligned under the ⋮ `anchor` it was invoked from.
    /// popup(parent, x, y) both parents and position-fits: the menu follows the
    /// row and flips itself when there is no room below, so there is no "above"
    /// to pass. options.forStrip marks a pill-strip open, options.hostPopup
    /// names the Popup it was invoked from. x stays bound (and guarded —
    /// closing the host destroys the anchor while the menu may still be open):
    /// the menu's width is 0 until content is first laid out.
    function openAt(record, anchor, options) {
        root.forStrip = !!(options && options.forStrip)
        root.hostPopup = (options && options.hostPopup) ?? null
        root.record = record
        root.popup(anchor, anchor.width - root.width, anchor.height)
        root.x = Qt.binding(() => anchor ? anchor.width - root.width : 0)
    }

    /// Called by actions that take the user out of the host — a new page behind
    /// it, or the OS file manager. Retry stays in the host, like a tap-to-retry.
    function _leaveHost() {
        if (root.hostPopup)
            root.hostPopup.close()
    }

    /// { openInBrowser, shareFile, shareUrl, showInFolder, retry, dismiss,
    ///   downloadsEntry, useShareLabels } — bind it:
    /// capabilities: ctx.capabilitiesFor(record, …)
    property var capabilities: null

    readonly property var _caps: root.capabilities ?? ({})

    // Mobile: Share file / Share URL. Desktop: Copy file path / Copy URL.
    readonly property bool _useShareLabels: !!_caps.useShareLabels

    readonly property bool isCancelled: record?.state === AbstractWebView.DownloadState.DownloadCancelled ?? false
    readonly property bool isComplete: record?.state === AbstractWebView.DownloadState.DownloadCompleted ?? false
    readonly property bool isInterrupted: record?.state === AbstractWebView.DownloadState.DownloadInterrupted ?? false
    readonly property bool isMissing: !!(record && record.missingFile)
    readonly property bool isPaused: {
        if (!record)
            return false
        return record.isPaused
            || record.state === AbstractWebView.DownloadState.DownloadPaused
    }
    readonly property bool isActiveTransfer: {
        if (!record || isComplete || isCancelled || isInterrupted)
            return false
        return record.state === AbstractWebView.DownloadState.DownloadInProgress
            || record.state === AbstractWebView.DownloadState.DownloadRequested
            || isPaused
    }

    readonly property string shareFileLabel: _useShareLabels ? qsTr("Share file") : qsTr("Copy file path")
    readonly property string shareUrlLabel: _useShareLabels ? qsTr("Share URL") : qsTr("Copy URL")
    readonly property string shareFileIcon: _useShareLabels
            ? (SQUtils.Utils.isIOS ? "share-ios" : "share-android")
            : "copy"
    readonly property string shareUrlIcon: _useShareLabels
            ? (SQUtils.Utils.isIOS ? "share-ios" : "share-android")
            : "copy"

    // Plain signals — callers already hold the menu's Record.
    signal downloadsRequested()
    signal showInFolderRequested()
    signal shareFileRequested()
    signal shareUrlRequested()
    signal openInBrowserRequested()
    signal retryRequested()
    signal dismissRequested()

    StatusAction {
        // Pill strip only (Figma pill menu): opens the Downloads List section
        // of the Open tabs overview. Absent in list menus — you are already there.
        enabled: !!root._caps.downloadsEntry
        icon.name: "download"
        text: qsTr("Downloads")
        onTriggered: root.downloadsRequested()
    }
    StatusMenuSeparator {
        visible: !!root._caps.downloadsEntry
    }
    StatusAction {
        enabled: isActiveTransfer && !isPaused
        icon.name: "pause"
        text: qsTr("Pause")
        onTriggered: root.record.pause()
    }
    StatusAction {
        enabled: isActiveTransfer && isPaused
        icon.name: "play"
        text: qsTr("Resume")
        onTriggered: root.record.resume()
    }
    StatusAction {
        enabled: isComplete && !!root._caps.openInBrowser
        icon.name: "browser"
        text: qsTr("Open in Browser")
        onTriggered: {
            root.openInBrowserRequested()
            root._leaveHost()
        }
    }
    StatusAction {
        enabled: isComplete && !!root._caps.shareFile
        icon.name: root.shareFileIcon
        text: root.shareFileLabel
        onTriggered: root.shareFileRequested()
    }
    StatusAction {
        enabled: (isComplete || isInterrupted || isCancelled) && !!root._caps.shareUrl
        icon.name: root.shareUrlIcon
        text: root.shareUrlLabel
        onTriggered: root.shareUrlRequested()
    }
    StatusAction {
        enabled: isComplete && !!root._caps.showInFolder
        icon.name: "show"
        text: qsTr("Show in folder")
        onTriggered: {
            root.showInFolderRequested()
            root._leaveHost()
        }
    }
    StatusAction {
        enabled: !!root._caps.retry
        icon.name: "refresh"
        text: qsTr("Retry")
        onTriggered: root.retryRequested()
    }
    StatusMenuSeparator {
        visible: isActiveTransfer || (!!root._caps.dismiss && (isComplete || isCancelled))
    }
    StatusAction {
        enabled: isActiveTransfer
        type: StatusAction.Type.Danger
        icon.name: "downloads-cancel"
        text: qsTr("Cancel")
        onTriggered: root.record.cancel()
    }
    StatusAction {
        // Pill strip only: remove Completed/Cancelled from the session strip.
        enabled: !!root._caps.dismiss && (isComplete || isCancelled)
        icon.name: "close"
        text: qsTr("Dismiss")
        onTriggered: root.dismissRequested()
    }
}
