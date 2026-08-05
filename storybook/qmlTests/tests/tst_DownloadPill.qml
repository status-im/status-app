import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.controls
import AppLayouts.Browser.panels

/**
 * Download Pill UI (browser-downloads-ux 01 + polish 02/04):
 * Figma control matrix, store-backed status wording, fixed strip width.
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
            property double receivedBytes: 400
            property double totalBytes: 1000
            property bool isPaused: false
            property bool isTerminal: false
            property bool missingFile: false
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

        function statusFn(store) {
            return function(record) { return store.statusText(record) }
        }

        function makePill(record, store, extras) {
            const props = Object.assign({
                download: record,
                width: 227,
                statusTextFn: statusFn(store)
            }, extras || {})
            return createTemporaryObject(pillComponent, root, props)
        }

        function test_inProgress_statusText_showsReceivedTotal() {
            const store = createStore()
            const record = createTemporaryObject(recordComponent, root, {
                receivedBytes: 400,
                totalBytes: 1000
            })
            const pill = makePill(record, store)
            verify(pill.statusText.indexOf("/") >= 0)
            compare(pill.statusText, store.statusText(record))
        }

        function test_paused_statusText_showsReceivedTotal_notPausedWord() {
            const store = createStore()
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadPaused,
                isPaused: true,
                receivedBytes: 400,
                totalBytes: 1000
            })
            const pill = makePill(record, store)
            verify(pill.statusText.indexOf("/") >= 0)
            verify(pill.statusText.indexOf(qsTr("Paused")) < 0)
            compare(pill.statusText, store.statusText(record))
        }

        function test_inProgress_pauseLeft_cancelRight_noOptions() {
            const store = createStore()
            const record = createTemporaryObject(recordComponent, root)
            const pill = makePill(record, store)

            compare(pill.primaryAction, DownloadPill.PrimaryAction.Pause)
            verify(pill.pauseButtonVisible)
            verify(!pill.resumeButtonVisible)
            verify(pill.cancelButtonVisible)
            verify(!pill.optionsButtonVisible)
        }

        function test_paused_resumeLeft_cancelRight_noOptions() {
            const store = createStore()
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadPaused,
                isPaused: true
            })
            const pill = makePill(record, store)

            compare(pill.primaryAction, DownloadPill.PrimaryAction.Resume)
            verify(pill.resumeButtonVisible)
            verify(!pill.pauseButtonVisible)
            verify(pill.cancelButtonVisible)
            verify(!pill.optionsButtonVisible)
        }

        function test_completed_fileLeft_optionsRight_noCancel_emptyStatus() {
            const store = createStore()
            const done = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted,
                isTerminal: true,
                receivedBytes: 1000
            })
            const pill = makePill(done, store)

            compare(pill.primaryAction, DownloadPill.PrimaryAction.File)
            verify(pill.optionsButtonVisible)
            verify(!pill.cancelButtonVisible)
            compare(pill.statusText, "")
            compare(store.statusText(done), "")
        }

        function test_cancelled_iconLeft_canceledStatus_noRightControl() {
            const store = createStore()
            const cancelled = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCancelled,
                isTerminal: true
            })
            const pill = makePill(cancelled, store)

            compare(pill.primaryAction, DownloadPill.PrimaryAction.Cancelled)
            compare(pill.statusText, qsTr("Canceled"))
            compare(store.statusText(cancelled), qsTr("Canceled"))
            verify(!pill.optionsButtonVisible)
            verify(!pill.cancelButtonVisible)
        }

        function test_interrupted_optionsRight_shortStatus_noInlineCancel() {
            const store = createStore()
            const interrupted = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadInterrupted,
                isTerminal: true
            })
            const pill = makePill(interrupted, store)

            compare(pill.primaryAction, DownloadPill.PrimaryAction.None)
            verify(pill.optionsButtonVisible)
            verify(!pill.cancelButtonVisible)
            compare(pill.statusText, qsTr("Interrupted"))
            compare(store.statusText(interrupted), qsTr("Interrupted"))
        }

        function test_cancelButton_forwardsToRecord() {
            const store = createStore()
            const record = createTemporaryObject(recordComponent, root)
            const pill = makePill(record, store)

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

        function test_strip_singlePill_keepsFixedWidth_leftAligned() {
            const store = createStore()
            const record = createTemporaryObject(recordComponent, root)
            const strip = createTemporaryObject(stripComponent, root, {
                statusTextFn: statusFn(store)
            })
            strip.downloadsModel = [record]
            strip.width = 360
            strip.height = 44
            waitForRendering(strip)

            compare(strip.pillWidth, 227)

            const listView = findChild(strip, "downloadPillListView")
            verify(!!listView)
            compare(listView.count, 1)
            const pill = listView.itemAtIndex(0)
            verify(!!pill)
            compare(pill.width, 227)
            // Lone pill must not stretch to the strip content width.
            verify(pill.width < listView.width)
        }

        function test_strip_multiPill_keepsFixedWidth_noShrink() {
            const store = createStore()
            const a = createTemporaryObject(recordComponent, root, { fileName: "a.pdf" })
            const b = createTemporaryObject(recordComponent, root, { fileName: "b.pdf" })
            const c = createTemporaryObject(recordComponent, root, { fileName: "c.pdf" })
            const strip = createTemporaryObject(stripComponent, root, {
                statusTextFn: statusFn(store)
            })
            strip.downloadsModel = [a, b, c]
            strip.width = 360
            strip.height = 44
            waitForRendering(strip)

            const listView = findChild(strip, "downloadPillListView")
            verify(!!listView)
            compare(listView.count, 3)
            compare(strip.pillWidth, 227)

            // Newest-first + positionViewAtBeginning → first pill is on-screen.
            listView.forceLayout()
            waitForRendering(strip)
            const first = listView.itemAtIndex(0)
            verify(!!first)
            compare(first.width, 227)

            // Three fixed 227px pills exceed the strip content area.
            verify(listView.contentWidth > listView.width)
            verify(listView.contentWidth >= strip.pillWidth * 3)
        }

        function test_strip_newDownload_insertsAtLeft() {
            const store = createStore()
            const older = createTemporaryObject(recordComponent, root, { fileName: "older.pdf" })
            const newer = createTemporaryObject(recordComponent, root, { fileName: "newer.pdf" })
            const strip = createTemporaryObject(stripComponent, root, {
                statusTextFn: statusFn(store)
            })
            strip.width = 600
            strip.height = 44
            strip.downloadsModel = [older]
            waitForRendering(strip)

            strip.downloadsModel = [newer, older]
            waitForRendering(strip)

            const listView = findChild(strip, "downloadPillListView")
            verify(!!listView)
            compare(listView.count, 2)
            listView.forceLayout()
            waitForRendering(strip)

            const left = listView.itemAtIndex(0)
            verify(!!left)
            compare(left.download, newer)
        }

        function test_strip_figmaChrome_flushPills_onlyActiveCardIsWhite() {
            const store = createStore()
            const active = createTemporaryObject(recordComponent, root, { fileName: "a.pdf" })
            const done = createTemporaryObject(recordComponent, root, {
                fileName: "b.pdf",
                state: AbstractWebView.DownloadState.DownloadCompleted,
                isTerminal: true
            })
            const strip = createTemporaryObject(stripComponent, root, {
                statusTextFn: statusFn(store)
            })
            strip.downloadsModel = [active, done]
            strip.width = 600
            waitForRendering(strip)

            compare(strip.implicitHeight, 44)

            const listView = findChild(strip, "downloadPillListView")
            verify(!!listView)
            listView.forceLayout()
            waitForRendering(strip)

            const first = listView.itemAtIndex(0)
            const second = listView.itemAtIndex(1)
            verify(!!first && !!second)
            verify(first.highlighted)
            verify(!second.highlighted)
            compare(first.height, strip.implicitHeight)

            // Pills sit flush — the strip tint separates them, not a gap.
            compare(second.x - first.x, strip.pillWidth)
            compare(second.color, strip.color)
            verify(first.color !== second.color)
        }

        function test_primaryPause_forwardsToRecord() {
            const store = createStore()
            const record = createTemporaryObject(recordComponent, root)
            const pill = makePill(record, store)

            pill.triggerPrimaryAction()
            compare(record.state, AbstractWebView.DownloadState.DownloadPaused)
            compare(pill.primaryAction, DownloadPill.PrimaryAction.Resume)

            pill.triggerPrimaryAction()
            compare(record.state, AbstractWebView.DownloadState.DownloadInProgress)
        }
    }
}
