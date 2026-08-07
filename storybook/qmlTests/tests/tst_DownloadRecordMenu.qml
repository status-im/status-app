import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ.Popups

import AppLayouts.Browser.adapters
import AppLayouts.Browser.popups

/**
 * Shared DownloadRecordMenu:
 * item sets + Share/Copy labels from one bound `capabilities` object.
 */
Item {
    id: root
    width: 400
    height: 400

    Component {
        id: recordComponent

        QtObject {
            property string fileName: "report.pdf"
            property url url: "https://example.com/report.pdf"
            property string targetPath: "/tmp/downloads/report.pdf"
            property string mimeType: "application/pdf"
            property int state: AbstractWebView.DownloadState.DownloadCompleted
            property double receivedBytes: 1000
            property double totalBytes: 1000
            property bool isPaused: false
            property bool isTerminal: true
            property bool missingFile: false
            property bool isInline: false
            property var liveDownload: null

            function pause() { isPaused = true; state = AbstractWebView.DownloadState.DownloadPaused }
            function resume() { isPaused = false; state = AbstractWebView.DownloadState.DownloadInProgress }
            function cancel() { isPaused = false; state = AbstractWebView.DownloadState.DownloadCancelled; isTerminal = true }
        }
    }

    Component {
        id: menuComponent
        DownloadRecordMenu {}
    }

    /// Stands in for the tabs/bookmarks overview the Downloads List lives in.
    Component {
        id: hostPopupComponent
        Popup {
            width: 200
            height: 200
        }
    }

    /// The row's ⋮ button the menu anchors to.
    Item {
        id: anchorItem
        width: 24
        height: 24
    }

    TestCase {
        name: "DownloadRecordMenu"
        when: windowShown

        /// One capabilities object per case.
        function caps(overrides) {
            return Object.assign({
                openInBrowser: false,
                shareFile: false,
                shareUrl: false,
                showInFolder: false,
                retry: false,
                dismiss: false,
                downloadsEntry: false,
                useShareLabels: false
            }, overrides || {})
        }

        function triggerAction(menu, text) {
            for (let i = 0; i < menu.count; ++i) {
                const action = menu.actionAt(i)
                if (action && action.enabled && action.text === text) {
                    action.trigger()
                    return true
                }
            }
            return false
        }

        function actionTexts(menu) {
            const texts = []
            for (let i = 0; i < menu.count; ++i) {
                const item = menu.itemAt(i)
                if (!item || item instanceof StatusMenuSeparator)
                    continue
                if (item.enabled && item.text)
                    texts.push(item.text)
            }
            return texts
        }

        function test_completed_desktop_copyLabels_andShowInFolder() {
            const record = createTemporaryObject(recordComponent, root)
            const menu = createTemporaryObject(menuComponent, root, {
                record: record,
                capabilities: caps({
                    openInBrowser: true,
                    shareFile: true,
                    shareUrl: true,
                    showInFolder: true
                })
            })

            const texts = actionTexts(menu)
            verify(texts.indexOf(qsTr("Copy file path")) >= 0)
            verify(texts.indexOf(qsTr("Copy file")) < 0)
            verify(texts.indexOf(qsTr("Copy URL")) >= 0)
            verify(texts.indexOf(qsTr("Open in Browser")) >= 0)
            verify(texts.indexOf(qsTr("Show in folder")) >= 0)
            verify(texts.indexOf(qsTr("Share file")) < 0)
            verify(texts.indexOf(qsTr("Pause")) < 0)
            verify(texts.indexOf(qsTr("Cancel")) < 0)
        }

        function test_completed_mobile_shareLabels_hideShowInFolderOnIos() {
            const record = createTemporaryObject(recordComponent, root)
            const menu = createTemporaryObject(menuComponent, root, {
                record: record,
                capabilities: caps({
                    shareFile: true,
                    shareUrl: true,
                    useShareLabels: true
                })
            })

            const texts = actionTexts(menu)
            verify(texts.indexOf(qsTr("Share file")) >= 0)
            verify(texts.indexOf(qsTr("Share URL")) >= 0)
            verify(texts.indexOf(qsTr("Show in folder")) < 0)
        }

        function test_active_list_exposesPauseResumeCancel() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadInProgress,
                isTerminal: false,
                receivedBytes: 100
            })
            const menu = createTemporaryObject(menuComponent, root, {
                record: record,
                capabilities: caps({ useShareLabels: true })
            })

            const texts = actionTexts(menu)
            verify(texts.indexOf(qsTr("Pause")) >= 0)
            verify(texts.indexOf(qsTr("Cancel")) >= 0)
            verify(texts.indexOf(qsTr("Share file")) < 0)

            record.pause()
            const paused = actionTexts(menu)
            verify(paused.indexOf(qsTr("Resume")) >= 0)
            verify(paused.indexOf(qsTr("Cancel")) >= 0)
        }

        function test_interrupted_retryAndUrlActions() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadInterrupted,
                isTerminal: true
            })
            const menu = createTemporaryObject(menuComponent, root, {
                record: record,
                capabilities: caps({ shareUrl: true, retry: true })
            })

            const texts = actionTexts(menu)
            verify(texts.indexOf(qsTr("Retry")) >= 0)
            verify(texts.indexOf(qsTr("Copy URL")) >= 0)
            verify(texts.indexOf(qsTr("Cancel")) < 0)
        }

        function test_pill_completed_canShowDismiss() {
            const record = createTemporaryObject(recordComponent, root)
            const menu = createTemporaryObject(menuComponent, root, {
                record: record,
                capabilities: caps({
                    shareFile: true,
                    shareUrl: true,
                    showInFolder: true,
                    dismiss: true,
                    useShareLabels: true
                })
            })

            const texts = actionTexts(menu)
            verify(texts.indexOf(qsTr("Dismiss")) >= 0)
        }

        function test_actionSignals_arePlain_recordIsTheMenus() {
            const record = createTemporaryObject(recordComponent, root)
            const menu = createTemporaryObject(menuComponent, root, {
                record: record,
                capabilities: caps({ retry: true, shareUrl: true })
            })

            let retried = 0
            menu.retryRequested.connect(function() { retried += 1 })
            menu.retryRequested()
            compare(retried, 1)
            // The caller reads the Record straight off the menu.
            compare(menu.record, record)
        }

        /// The pill strip menu leads with "Downloads" (opens the
        /// Downloads List section of the Open tabs overview), above a divider.
        function test_downloadsEntry_firstInStripMenu_emitsSignal() {
            const record = createTemporaryObject(recordComponent, root)
            const menu = createTemporaryObject(menuComponent, root, {
                record: record,
                capabilities: caps({
                    shareFile: true,
                    shareUrl: true,
                    showInFolder: true,
                    dismiss: true,
                    downloadsEntry: true
                })
            })

            const texts = actionTexts(menu)
            verify(texts.indexOf(qsTr("Downloads")) >= 0)
            compare(texts[0], qsTr("Downloads"), "Downloads leads the strip menu")

            let opened = 0
            menu.downloadsRequested.connect(function() { opened += 1 })
            for (let i = 0; i < menu.count; ++i) {
                const action = menu.actionAt(i)
                if (action && action.enabled && action.text === qsTr("Downloads"))
                    action.trigger()
            }
            compare(opened, 1, "activating the entry requests the Downloads List")
        }

        /// List-row menus never show the entry — the user is already
        /// in the Downloads List.
        function test_downloadsEntry_absentFromListMenus() {
            const record = createTemporaryObject(recordComponent, root)
            const menu = createTemporaryObject(menuComponent, root, {
                record: record,
                capabilities: caps({
                    openInBrowser: true,
                    shareFile: true,
                    shareUrl: true,
                    showInFolder: true
                })
            })

            const texts = actionTexts(menu)
            verify(texts.indexOf(qsTr("Downloads")) < 0)
        }

        /// `capabilities` is a BINDING at the call site, so the menu
        /// can never show stale capabilities — flipping the record's state
        /// re-derives the object with no populate step in between.
        function test_capabilitiesBinding_followsRecordState_noStaleMenu() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadInProgress,
                isTerminal: false
            })
            const menu = createTemporaryObject(menuComponent, root, {
                record: record
            })
            const self = this
            menu.capabilities = Qt.binding(function() {
                const complete = !!menu.record
                    && menu.record.state === AbstractWebView.DownloadState.DownloadCompleted
                return self.caps({
                    openInBrowser: complete,
                    shareFile: complete,
                    shareUrl: true
                })
            })

            let texts = actionTexts(menu)
            verify(texts.indexOf(qsTr("Open in Browser")) < 0)
            verify(texts.indexOf(qsTr("Pause")) >= 0)

            record.state = AbstractWebView.DownloadState.DownloadCompleted
            record.isTerminal = true

            texts = actionTexts(menu)
            verify(texts.indexOf(qsTr("Open in Browser")) >= 0,
                   "capabilities re-derive from the record with no populate call")
            verify(texts.indexOf(qsTr("Copy file path")) >= 0)
            verify(texts.indexOf(qsTr("Pause")) < 0)
        }

        /// Opening the file in the browser leaves the overview behind, so the
        /// menu closes it — a plain row tap already closes it in the host.
        function test_openInBrowser_closesTheHostPopup() {
            const host = createTemporaryObject(hostPopupComponent, root)
            host.open()
            tryCompare(host, "opened", true)

            const record = createTemporaryObject(recordComponent, root)
            const menu = createTemporaryObject(menuComponent, root, {
                capabilities: caps({ openInBrowser: true, shareUrl: true, showInFolder: true })
            })
            menu.openAnchored(record, anchorItem, { hostPopup: host })
            compare(menu.hostPopup, host)

            let opened = 0
            menu.openInBrowserRequested.connect(function() { opened += 1 })
            verify(triggerAction(menu, qsTr("Open in Browser")))
            compare(opened, 1)
            tryCompare(host, "visible", false, 1000,
                       "the overview must not stay on top of the page we navigated to")
        }

        /// Retry re-issues the download and the user stays in the list —
        /// same as tap-to-retry, which does not close the overview either.
        function test_retry_keepsTheHostPopupOpen() {
            const host = createTemporaryObject(hostPopupComponent, root)
            host.open()
            tryCompare(host, "opened", true)

            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadInterrupted
            })
            const menu = createTemporaryObject(menuComponent, root, {
                capabilities: caps({ retry: true, shareUrl: true })
            })
            menu.openAnchored(record, anchorItem, { hostPopup: host })

            let retried = 0
            menu.retryRequested.connect(function() { retried += 1 })
            verify(triggerAction(menu, qsTr("Retry")))
            compare(retried, 1)
            verify(host.visible, "Retry keeps the user in the Downloads List")
        }

        /// Pill strip opens have no host — the previous list open must not
        /// leave one behind.
        function test_stripOpen_clearsTheHostPopup() {
            const host = createTemporaryObject(hostPopupComponent, root)
            host.open()

            const record = createTemporaryObject(recordComponent, root)
            const menu = createTemporaryObject(menuComponent, root, {
                capabilities: caps({ openInBrowser: true })
            })
            menu.openAnchored(record, anchorItem, { hostPopup: host })
            compare(menu.hostPopup, host)

            menu.openAnchored(record, anchorItem, { forStrip: true })
            compare(menu.hostPopup, null)

            verify(triggerAction(menu, qsTr("Open in Browser")))
            verify(host.visible, "a strip menu never closes an unrelated popup")
        }
    }
}
