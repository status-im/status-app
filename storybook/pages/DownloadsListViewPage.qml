import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Storybook

import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import AppLayouts.Browser.adapters
import AppLayouts.Browser.panels
import AppLayouts.Browser.popups
import AppLayouts.Browser.webview
import AppLayouts.Browser.stores as BrowserStores

// Downloads List and the Record menu it opens, on fake Records — one row per
// Download state, so the per-state menu can be exercised without a browser,
// a profile or a real transfer.
SplitView {
    id: root

    orientation: Qt.Horizontal

    QtObject {
        id: d

        // The Record vocabulary the pill and the menu read (ADR 0006 §2).
        function record(fileName, state, missingFile) {
            return {
                fileName: fileName,
                url: "https://example.com/" + fileName,
                targetPath: "/tmp/status-storybook-downloads/" + fileName,
                mimeType: "application/pdf",
                state: state,
                isPaused: state === AbstractWebView.DownloadState.DownloadPaused,
                missingFile: !!missingFile,
                isInline: false,
                receivedBytes: 512 * 1024,
                totalBytes: 1024 * 1024,
                offTheRecord: false,
                pause: function() {},
                resume: function() {},
                cancel: function() {}
            }
        }

        readonly property var records: [
            d.record("cancelled.pdf", AbstractWebView.DownloadState.DownloadCancelled),
            d.record("interrupted.pdf", AbstractWebView.DownloadState.DownloadInterrupted),
            d.record("completed.pdf", AbstractWebView.DownloadState.DownloadCompleted),
            d.record("missing.pdf", AbstractWebView.DownloadState.DownloadCompleted, true),
            d.record("in-progress.pdf", AbstractWebView.DownloadState.DownloadInProgress),
            d.record("paused.pdf", AbstractWebView.DownloadState.DownloadPaused)
        ]
    }

    Item {
        SplitView.fillWidth: true
        SplitView.fillHeight: true

        // The overview hosts the list inside a Popup; the menu anchors to a ⋮
        // button that lives in there, so reproduce that nesting here.
        Button {
            objectName: "openDownloadsHostButton"
            anchors.centerIn: parent
            text: "Open Downloads popup"
            onClicked: hostPopup.open()
        }

        // The overview is a StatusDialog; reproduce that exact host, since a
        // Menu anchored inside one is the case the app gets wrong.
        StatusDialog {
            id: hostPopup
            objectName: "downloadsHostPopup"
            width: 420
            height: 460
            title: "Downloads"

            ColumnLayout {
                anchors.fill: parent

                Button {
                    objectName: "dialogOpenMenuButton"
                    text: "Open menu anchored here"
                    onClicked: {
                        logLabel.text = "dialog menu for: " + d.records[0].fileName
                        recordMenu.openAt(d.records[0], this, { hostPopup: hostPopup })
                    }
                }

                DownloadsListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    downloadsModel: d.records

                    onOptionsClicked: (record, anchor) => {
                        logLabel.text = "popup menu for: " + record.fileName + " state=" + record.state
                        recordMenu.openAt(record, anchor, { hostPopup: hostPopup })
                    }
                    onScrolled: recordMenu.close()
                    onOpenDownloadClicked: (record) => logLabel.text = "open: " + record.fileName
                }
            }
        }

        // Same list outside any Popup — the pill-strip case, for comparison.
        DownloadsListView {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Theme.padding
            width: 380
            height: 300
            downloadsModel: d.records

            onOptionsClicked: (record, anchor) => {
                logLabel.text = "menu for: " + record.fileName + " state=" + record.state
                recordMenu.openAt(record, anchor, {})
            }
            onScrolled: recordMenu.close()
            onOpenDownloadClicked: (record) => logLabel.text = "open: " + record.fileName
        }
    }

    // The production capability vocabulary — same code path as BrowserLayout,
    // so the menu here is gated exactly as it is in the app.
    BrowserDownloadsContext {
        id: downloadsContext

        downloadsStore: BrowserStores.DownloadsStore {
            property var platform: ({ fileExists: function(p) { return true },
                                      preferShareSheet: ctrlShareLabels.checked,
                                      showInFolderSupported: true })
            function refreshMissingFiles() {}
            function canShareFile(record) {
                return !!record && !record.missingFile
                    && record.state === AbstractWebView.DownloadState.DownloadCompleted
                    && !!record.targetPath
            }
            function canShareUrl(record) { return !!record && !!record.url }
            function canShowInFolder(record) { return canShareFile(record) }
            function canRetryFromMenu(record) {
                return !!record && !record.isInline
                    && (record.state === AbstractWebView.DownloadState.DownloadInterrupted
                        || record.state === AbstractWebView.DownloadState.DownloadCancelled)
            }
        }
        downloadUrlFn: function(wantOtr, url, fileName, token) { return true }
    }

    DownloadRecordMenu {
        id: recordMenu

        capabilities: ctrlRealCaps.checked
                      ? downloadsContext.capabilitiesFor(record, {})
                      : ({
            openInBrowser: !!record && record.state === AbstractWebView.DownloadState.DownloadCompleted
                           && !record.missingFile,
            shareFile: !!record && record.state === AbstractWebView.DownloadState.DownloadCompleted
                       && !record.missingFile,
            shareUrl: !!record,
            showInFolder: !!record && record.state === AbstractWebView.DownloadState.DownloadCompleted
                          && !record.missingFile,
            retry: !!record && (record.state === AbstractWebView.DownloadState.DownloadCancelled
                                || record.state === AbstractWebView.DownloadState.DownloadInterrupted),
            dismiss: false,
            downloadsEntry: false,
            useShareLabels: ctrlShareLabels.checked
        })

        onRetryRequested: logLabel.text = "retry: " + record.fileName
        onOpenInBrowserRequested: logLabel.text = "openInBrowser: " + record.fileName
        onShowInFolderRequested: logLabel.text = "showInFolder: " + record.fileName
        onShareFileRequested: logLabel.text = "shareFile: " + record.fileName
        onShareUrlRequested: logLabel.text = "shareUrl: " + record.fileName
    }

    LogsAndControlsPanel {
        SplitView.minimumWidth: 250
        SplitView.preferredWidth: 300

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Label {
                id: logLabel
                objectName: "menuActionLabel"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "—"
            }

            Switch {
                id: ctrlShareLabels
                text: "Mobile share labels"
            }

            Switch {
                id: ctrlRealCaps
                text: "Real capabilitiesFor()"
                checked: true
            }

            Item { Layout.fillHeight: true }
        }
    }
}

// category: Browser
