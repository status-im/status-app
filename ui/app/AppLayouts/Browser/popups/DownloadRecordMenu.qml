import QtQuick

import StatusQ.Popups
import StatusQ.Core.Utils as SQUtils

import AppLayouts.Browser.adapters

/**
 * One download menu for Download Pill and Downloads List (browser-downloads-ux 02).
 * Capability + Record state driven; Share vs Copy labels via useShareLabels.
 * StatusAction has no visible; StatusMenu hides disabled items by default.
 */
StatusMenu {
    id: root

    property var record: null
    property int index: -1

    // Mobile: Share file / Share URL. Desktop: Copy file path / Copy URL.
    property bool useShareLabels: SQUtils.Utils.isMobile

    property bool canShareFile: false
    property bool canShareUrl: false
    property bool canOpenInBrowser: false
    property bool canShowInFolder: false
    property bool canRetry: false

    // Pill strip only: remove Completed/Cancelled from the session strip.
    property bool showDismiss: false

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

    readonly property string shareFileLabel: useShareLabels ? qsTr("Share file") : qsTr("Copy file path")
    readonly property string shareUrlLabel: useShareLabels ? qsTr("Share URL") : qsTr("Copy URL")
    readonly property string shareFileIcon: useShareLabels
            ? (SQUtils.Utils.isIOS ? "share-ios" : "share-android")
            : "copy"
    readonly property string shareUrlIcon: useShareLabels
            ? (SQUtils.Utils.isIOS ? "share-ios" : "share-android")
            : "copy"

    signal showInFolderRequested(int index)
    signal shareFileRequested(int index)
    signal shareUrlRequested(int index)
    signal openInBrowserRequested(int index)
    signal retryRequested(int index)
    signal dismissRequested(int index)

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
        enabled: isComplete && root.canOpenInBrowser
        icon.name: "browser"
        text: qsTr("Open in Browser")
        onTriggered: root.openInBrowserRequested(root.index)
    }
    StatusAction {
        enabled: isComplete && root.canShareFile
        icon.name: root.shareFileIcon
        text: root.shareFileLabel
        onTriggered: root.shareFileRequested(root.index)
    }
    StatusAction {
        enabled: (isComplete || isInterrupted || isCancelled) && root.canShareUrl
        icon.name: root.shareUrlIcon
        text: root.shareUrlLabel
        onTriggered: root.shareUrlRequested(root.index)
    }
    StatusAction {
        enabled: isComplete && root.canShowInFolder
        icon.name: "show"
        text: qsTr("Show in folder")
        onTriggered: root.showInFolderRequested(root.index)
    }
    StatusAction {
        enabled: root.canRetry
        icon.name: "refresh"
        text: qsTr("Retry")
        onTriggered: root.retryRequested(root.index)
    }
    StatusMenuSeparator {
        visible: isActiveTransfer || (root.showDismiss && (isComplete || isCancelled))
    }
    StatusAction {
        enabled: isActiveTransfer
        type: StatusAction.Type.Danger
        icon.name: "downloads-cancel"
        text: qsTr("Cancel")
        onTriggered: root.record.cancel()
    }
    StatusAction {
        enabled: root.showDismiss && (isComplete || isCancelled)
        icon.name: "close"
        text: qsTr("Dismiss")
        onTriggered: root.dismissRequested(root.index)
    }
}
