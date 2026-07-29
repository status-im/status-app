import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.controls
import AppLayouts.Browser.panels

/**
 * Download Pill UI (browser-downloads-ux 01): Figma control matrix + filename elide.
 */
Item {
    id: root
    width: 360
    height: 200

    readonly property url downloadsStoreUrl: Qt.resolvedUrl(
        "../../../ui/app/AppLayouts/Browser/stores/DownloadsStore.qml")

    Component {
        id: recordComponent

        QtObject {
            property string fileName: "report.pdf"
            property url url: "https://example.com/report.pdf"
            property int state: AbstractWebView.DownloadState.DownloadInProgress
            property int receivedBytes: 400
            property int totalBytes: 1000
            property bool isPaused: false
            property bool isTerminal: false
            property var liveDownload: null

            function pause() { isPaused = true; state = AbstractWebView.DownloadState.DownloadPaused }
            function resume() { isPaused = false; state = AbstractWebView.DownloadState.DownloadInProgress }
            function cancel() { isPaused = false; state = AbstractWebView.DownloadState.DownloadCancelled; isTerminal = true }
        }
    }

    Component {
        id: pillComponent
        DownloadPill {}
    }

    Component {
        id: stripComponent
        DownloadPillStrip {
            width: 360
        }
    }

    TestCase {
        name: "DownloadPill"
        when: windowShown

        function createStore() {
            const component = Qt.createComponent(root.downloadsStoreUrl)
            verify(component.status === Component.Ready, component.errorString())
            const store = createTemporaryObject(component, root)
            store.ensureDirectoryFn = function(path) { return true }
            return store
        }

        function test_inProgress_statusText_showsReceivedTotal() {
            const record = createTemporaryObject(recordComponent, root, {
                receivedBytes: 400,
                totalBytes: 1000
            })
            const pill = createTemporaryObject(pillComponent, root, { download: record, width: 236 })
            verify(pill.statusText.indexOf("/") >= 0)
        }

        function test_inProgress_pauseLeft_cancelRight_noOptions() {
            const record = createTemporaryObject(recordComponent, root)
            const pill = createTemporaryObject(pillComponent, root, { download: record, width: 236 })

            compare(pill.primaryAction, DownloadPill.PrimaryAction.Pause)
            verify(pill.pauseButtonVisible)
            verify(!pill.resumeButtonVisible)
            verify(pill.cancelButtonVisible)
            verify(!pill.optionsButtonVisible)
        }

        function test_paused_resumeLeft_cancelRight_noOptions() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadPaused,
                isPaused: true
            })
            const pill = createTemporaryObject(pillComponent, root, { download: record, width: 236 })

            compare(pill.primaryAction, DownloadPill.PrimaryAction.Resume)
            verify(pill.resumeButtonVisible)
            verify(!pill.pauseButtonVisible)
            verify(pill.cancelButtonVisible)
            verify(!pill.optionsButtonVisible)
        }

        function test_completed_fileLeft_optionsRight_noCancel() {
            const done = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted,
                isTerminal: true,
                receivedBytes: 1000
            })
            const pill = createTemporaryObject(pillComponent, root, { download: done, width: 236 })

            compare(pill.primaryAction, DownloadPill.PrimaryAction.File)
            verify(pill.optionsButtonVisible)
            verify(!pill.cancelButtonVisible)
            compare(pill.statusText, "")
        }

        function test_cancelled_iconLeft_canceledStatus_noRightControl() {
            const cancelled = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCancelled,
                isTerminal: true
            })
            const pill = createTemporaryObject(pillComponent, root, { download: cancelled, width: 236 })

            compare(pill.primaryAction, DownloadPill.PrimaryAction.Cancelled)
            compare(pill.statusText, qsTr("Canceled"))
            verify(!pill.optionsButtonVisible)
            verify(!pill.cancelButtonVisible)
        }

        function test_interrupted_optionsRight_noInlineCancel() {
            const interrupted = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadInterrupted,
                isTerminal: true
            })
            const pill = createTemporaryObject(pillComponent, root, { download: interrupted, width: 236 })

            compare(pill.primaryAction, DownloadPill.PrimaryAction.None)
            verify(pill.optionsButtonVisible)
            verify(!pill.cancelButtonVisible)
            compare(pill.statusText, qsTr("Interrupted"))
        }

        function test_cancelButton_forwardsToRecord() {
            const record = createTemporaryObject(recordComponent, root)
            const pill = createTemporaryObject(pillComponent, root, { download: record, width: 236 })

            pill.triggerCancel()
            compare(record.state, AbstractWebView.DownloadState.DownloadCancelled)
            compare(pill.primaryAction, DownloadPill.PrimaryAction.Cancelled)
            verify(!pill.cancelButtonVisible)
            verify(!pill.optionsButtonVisible)
        }

        function test_elideFileName_middleElidesBase_keepsExtension() {
            const store = createStore()
            const longName = "very-long-download-report-name.pdf"
            const elided = store.elideFileName(longName, 18)

            verify(elided.endsWith(".pdf"))
            verify(elided.indexOf("…") >= 0 || elided.indexOf("...") >= 0)
            verify(elided.length <= 18)
            compare(store.elideFileName("short.pdf", 40), "short.pdf")
            compare(store.elideFileName("noext", 4).length <= 4, true)
        }

        function test_strip_singlePill_usesFullWidth() {
            const record = createTemporaryObject(recordComponent, root)
            const strip = createTemporaryObject(stripComponent, root)
            strip.downloadsModel = [record]
            strip.width = 360
            strip.height = 52
            waitForRendering(strip)

            compare(strip.pillWidthForCount(320, 1), 320)

            const listView = findChild(strip, "downloadPillListView")
            verify(!!listView)
            compare(listView.count, 1)
            const pill = listView.itemAtIndex(0)
            verify(!!pill)
            verify(pill.width >= listView.width - 1)
        }

        function test_strip_multiPill_clampsMin128Max236() {
            const a = createTemporaryObject(recordComponent, root, { fileName: "a.pdf" })
            const b = createTemporaryObject(recordComponent, root, { fileName: "b.pdf" })
            const strip = createTemporaryObject(stripComponent, root)
            strip.downloadsModel = [a, b]
            strip.width = 360
            strip.height = 52
            waitForRendering(strip)

            const w = strip.pillWidthForCount(300, 2)
            verify(w >= 128)
            verify(w <= 236)

            const listView = findChild(strip, "downloadPillListView")
            verify(!!listView)
            compare(listView.count, 2)
            for (let i = 0; i < 2; ++i) {
                const pill = listView.itemAtIndex(i)
                verify(!!pill)
                verify(pill.width >= 128)
                verify(pill.width <= 236)
            }
        }

        function test_primaryPause_forwardsToRecord() {
            const record = createTemporaryObject(recordComponent, root)
            const pill = createTemporaryObject(pillComponent, root, { download: record, width: 236 })

            pill.triggerPrimaryAction()
            compare(record.state, AbstractWebView.DownloadState.DownloadPaused)
            compare(pill.primaryAction, DownloadPill.PrimaryAction.Resume)

            pill.triggerPrimaryAction()
            compare(record.state, AbstractWebView.DownloadState.DownloadInProgress)
        }
    }
}
