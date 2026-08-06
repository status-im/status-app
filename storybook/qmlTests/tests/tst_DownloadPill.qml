import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.controls
import AppLayouts.Browser.panels

import "../../../ui/app/AppLayouts/Browser/webview/DownloadFormatUtils.js" as DownloadFormatUtils

/**
 * Download Pill UI:
 * Figma control matrix, status wording, fixed strip width.
 */
Item {
    id: root
    width: 360
    height: 200

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

        function makePill(record, extras) {
            const props = Object.assign({
                download: record,
                width: 227
            }, extras || {})
            return createTemporaryObject(pillComponent, root, props)
        }

        function test_inProgress_statusText_showsReceivedTotal() {
            const record = createTemporaryObject(recordComponent, root, {
                receivedBytes: 400,
                totalBytes: 1000
            })
            const pill = makePill(record)
            verify(pill.statusText.indexOf("/") >= 0)
        }

        function test_paused_statusText_showsReceivedTotal_notPausedWord() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadPaused,
                isPaused: true,
                receivedBytes: 400,
                totalBytes: 1000
            })
            const pill = makePill(record)
            verify(pill.statusText.indexOf("/") >= 0)
            verify(pill.statusText.indexOf(qsTr("Paused")) < 0)
        }

        // Regression: a wrapped 32-bit byte count rendered negative sizes.
        function test_statusText_survivesFilesOver2GiB() {
            const record = createTemporaryObject(recordComponent, root, {
                totalBytes: 3 * 1024 * 1024 * 1024,      // 3 GiB > 2^31
                receivedBytes: 2.5 * 1024 * 1024 * 1024
            })
            const pill = makePill(record)

            const text = pill.statusText
            verify(text.indexOf("/") >= 0)
            verify(text.indexOf("-") < 0, "overflowed to negative: " + text)
            verify(text.indexOf("GB") >= 0, "expected GB sizes, got: " + text)
        }

        // Missing File outranks the Record state in the subtitle.
        function test_missingFile_statusText_overridesState() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted,
                isTerminal: true,
                missingFile: true
            })
            const pill = makePill(record)
            compare(pill.statusText, qsTr("Missing file"))
        }

        function test_inProgress_pauseLeft_cancelRight_noOptions() {
            const record = createTemporaryObject(recordComponent, root)
            const pill = makePill(record)

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
            const pill = makePill(record)

            compare(pill.primaryAction, DownloadPill.PrimaryAction.Resume)
            verify(pill.resumeButtonVisible)
            verify(!pill.pauseButtonVisible)
            verify(pill.cancelButtonVisible)
            verify(!pill.optionsButtonVisible)

            // The rendered controls follow the flags.
            const primary = findChild(pill, "downloadPillPrimaryButton")
            verify(!!primary)
            verify(primary.visible)
            compare(primary.icon.name, "play")

            const cancel = findChild(pill, "downloadPillCancelButton")
            verify(!!cancel)
            verify(cancel.visible)

            const options = findChild(pill, "downloadPillOptionsButton")
            verify(!!options)
            verify(!options.visible)
        }

        function test_completed_fileLeft_optionsRight_noCancel_emptyStatus() {
            const done = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted,
                isTerminal: true,
                receivedBytes: 1000
            })
            const pill = makePill(done)

            compare(pill.primaryAction, DownloadPill.PrimaryAction.File)
            verify(pill.optionsButtonVisible)
            verify(!pill.cancelButtonVisible)
            compare(pill.statusText, "")
        }

        function test_cancelled_iconLeft_cancelledStatus_hasOptionsMenu() {
            // Cancelled keeps its ⋮ so Retry/Dismiss stay reachable from the strip.
            const cancelled = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCancelled,
                isTerminal: true
            })
            const pill = makePill(cancelled)

            compare(pill.primaryAction, DownloadPill.PrimaryAction.Cancelled)
            compare(pill.statusText, qsTr("Cancelled"))
            verify(pill.optionsButtonVisible)
            verify(!pill.cancelButtonVisible)
        }

        function test_interrupted_optionsRight_shortStatus_noInlineCancel() {
            const interrupted = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadInterrupted,
                isTerminal: true
            })
            const pill = makePill(interrupted)

            compare(pill.primaryAction, DownloadPill.PrimaryAction.None)
            verify(pill.optionsButtonVisible)
            verify(!pill.cancelButtonVisible)
            compare(pill.statusText, qsTr("Interrupted"))
        }

        function test_cancelButton_forwardsToRecord() {
            const record = createTemporaryObject(recordComponent, root)
            const pill = makePill(record)

            pill.triggerCancel()
            compare(record.state, AbstractWebView.DownloadState.DownloadCancelled)
            compare(pill.primaryAction, DownloadPill.PrimaryAction.Cancelled)
            verify(!pill.cancelButtonVisible)
            verify(pill.optionsButtonVisible) // Cancelled keeps its ⋮
        }

        // Missing File follows the Record, not the surface — the strikeout
        // lives in the pill, so both strip and list rows get it.
        function test_missingFile_strikesThroughFileName() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted,
                isTerminal: true,
                missingFile: true
            })
            const pill = makePill(record)

            const label = findChild(pill, "downloadPillFileNameLabel")
            verify(!!label)
            verify(label.font.strikeout, "Missing File strikes through the file name")
        }

        function test_elideFileName_middleElidesBase_keepsExtension() {
            const longName = "very-long-download-report-name.pdf"
            const elided = DownloadFormatUtils.elideFileName(longName, 18)

            verify(elided.endsWith(".pdf"))
            verify(elided.indexOf("…") >= 0 || elided.indexOf("...") >= 0)
            verify(elided.length <= 18)
            compare(DownloadFormatUtils.elideFileName("short.pdf", 40), "short.pdf")
            compare(DownloadFormatUtils.elideFileName("noext", 4).length <= 4, true)
        }

        function test_strip_singlePill_keepsFixedWidth_leftAligned() {
            const record = createTemporaryObject(recordComponent, root)
            const strip = createTemporaryObject(stripComponent, root)
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
            const a = createTemporaryObject(recordComponent, root, { fileName: "a.pdf" })
            const b = createTemporaryObject(recordComponent, root, { fileName: "b.pdf" })
            const c = createTemporaryObject(recordComponent, root, { fileName: "c.pdf" })
            const strip = createTemporaryObject(stripComponent, root)
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
            const older = createTemporaryObject(recordComponent, root, { fileName: "older.pdf" })
            const newer = createTemporaryObject(recordComponent, root, { fileName: "newer.pdf" })
            const strip = createTemporaryObject(stripComponent, root)
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
            const active = createTemporaryObject(recordComponent, root, { fileName: "a.pdf" })
            const done = createTemporaryObject(recordComponent, root, {
                fileName: "b.pdf",
                state: AbstractWebView.DownloadState.DownloadCompleted,
                isTerminal: true
            })
            const strip = createTemporaryObject(stripComponent, root)
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

        // Strip signals carry the Download Record, not a strip index.
        function test_strip_click_and_options_emitTheRecord() {
            const done = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted,
                isTerminal: true
            })
            const strip = createTemporaryObject(stripComponent, root)
            strip.downloadsModel = [done]
            strip.width = 360
            strip.height = 44
            waitForRendering(strip)

            const listView = findChild(strip, "downloadPillListView")
            verify(!!listView)
            const pill = listView.itemAtIndex(0)
            verify(!!pill)

            let clicked = null
            strip.openDownloadClicked.connect(function (r) { clicked = r })
            pill.itemClicked()
            compare(clicked, done)

            let gotRecord = null
            let gotAnchor = null
            strip.optionsClicked.connect(function (r, anchor) {
                gotRecord = r
                gotAnchor = anchor
            })
            const options = findChild(pill, "downloadPillOptionsButton")
            verify(!!options)
            verify(options.visible)
            mouseClick(options)
            compare(gotRecord, done)
            verify(!!gotAnchor, "anchor Item for menu alignment")
        }

        function test_primaryPause_forwardsToRecord() {
            const record = createTemporaryObject(recordComponent, root)
            const pill = makePill(record)

            pill.triggerPrimaryAction()
            compare(record.state, AbstractWebView.DownloadState.DownloadPaused)
            compare(pill.primaryAction, DownloadPill.PrimaryAction.Resume)

            pill.triggerPrimaryAction()
            compare(record.state, AbstractWebView.DownloadState.DownloadInProgress)
        }
    }
}
