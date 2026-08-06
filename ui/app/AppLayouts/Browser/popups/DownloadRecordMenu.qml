import QtQuick

import StatusQ.Popups
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Browser.adapters

/**
 * One download menu for Download Pill and Downloads List (browser-downloads-ux 02).
 * Identity is the Download Record; enablement comes from one `capabilities`
 * object (BrowserDownloadsContext.capabilitiesFor) BOUND at the call site, so
 * the menu can never show stale capabilities (ticket 09). State-derived
 * booleans stay internal. Share vs Copy labels via capabilities.useShareLabels.
 * StatusAction has no visible; StatusMenu hides disabled items by default.
 */
StatusMenu {
    id: root

    property var record: null

    /// { openInBrowser, shareFile, shareUrl, showInFolder, retry, dismiss,
    ///   useShareLabels } — bind it: capabilities: ctx.capabilitiesFor(record, …)
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

    // Plain signals — callers already hold the menu's Record (ticket 09).
    signal showInFolderRequested()
    signal shareFileRequested()
    signal shareUrlRequested()
    signal openInBrowserRequested()
    signal retryRequested()
    signal dismissRequested()

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
        onTriggered: root.openInBrowserRequested()
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
        onTriggered: root.showInFolderRequested()
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
