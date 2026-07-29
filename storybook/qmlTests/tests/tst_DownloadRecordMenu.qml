import QtQuick
import QtTest

import StatusQ.Popups

import AppLayouts.Browser.adapters
import AppLayouts.Browser.popups

/**
 * Shared DownloadRecordMenu (browser-downloads-ux 02): item sets + Share/Copy labels.
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
            property int receivedBytes: 1000
            property int totalBytes: 1000
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

    TestCase {
        name: "DownloadRecordMenu"
        when: windowShown

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
                index: 0,
                useShareLabels: false,
                canShareFile: true,
                canShareUrl: true,
                canOpenInBrowser: true,
                canShowInFolder: true,
                canRetry: false,
                showDismiss: false
            })

            const texts = actionTexts(menu)
            verify(texts.indexOf(qsTr("Copy file")) >= 0)
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
                index: 0,
                useShareLabels: true,
                canShareFile: true,
                canShareUrl: true,
                canOpenInBrowser: false,
                canShowInFolder: false,
                canRetry: false
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
                index: 0,
                useShareLabels: true,
                canShareFile: false,
                canShareUrl: false,
                canOpenInBrowser: false,
                canShowInFolder: false,
                canRetry: false
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
                index: 0,
                useShareLabels: false,
                canShareFile: false,
                canShareUrl: true,
                canOpenInBrowser: false,
                canShowInFolder: false,
                canRetry: true
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
                index: 0,
                useShareLabels: true,
                canShareFile: true,
                canShareUrl: true,
                canOpenInBrowser: false,
                canShowInFolder: true,
                canRetry: false,
                showDismiss: true
            })

            const texts = actionTexts(menu)
            verify(texts.indexOf(qsTr("Dismiss")) >= 0)
        }
    }
}
