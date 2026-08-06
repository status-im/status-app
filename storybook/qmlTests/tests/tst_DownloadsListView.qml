import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.controls
import AppLayouts.Browser.panels

/**
 * DownloadsListView (browser-downloads-polish 01): empty line only at zero Records.
 * Model may arrive via object construction (BrowserLayout → createObject), where a
 * JS array is converted and no longer reports as Array — count must use .length.
 * Active rows mirror Download Pill Pause|Resume / Cancel controls.
 */
Item {
    id: root
    width: 360
    height: 400

    Component {
        id: recordComponent

        QtObject {
            property string fileName: "report.pdf"
            property url url: "https://example.com/report.pdf"
            property int state: AbstractWebView.DownloadState.DownloadCompleted
            property bool isPaused: false
            property bool missingFile: false

            function pause() {
                isPaused = true
                state = AbstractWebView.DownloadState.DownloadPaused
            }
            function resume() {
                isPaused = false
                state = AbstractWebView.DownloadState.DownloadInProgress
            }
            function cancel() {
                isPaused = false
                state = AbstractWebView.DownloadState.DownloadCancelled
            }
        }
    }

    Component {
        id: listViewComponent

        DownloadsListView {
            width: 360
            height: 400
        }
    }

    TestCase {
        name: "DownloadsListView"
        when: windowShown

        function emptyLabel(view) {
            return findChild(view, "downloadsListEmptyLabel")
        }

        function listRow(view, index) {
            const list = findChild(view, "downloadsListView")
            verify(!!list)
            list.forceLayout()
            waitForRendering(view)
            const row = list.itemAtIndex(index)
            verify(!!row, "list row " + index)
            return row
        }

        // Rows render through the shared DownloadPill delegate (polish 03).
        function rowPill(view, index) {
            const pill = findChild(listRow(view, index), "downloadPill")
            verify(!!pill, "row " + index + " renders the shared DownloadPill")
            return pill
        }

        function test_empty_placeholder_visible_when_noRecords() {
            const view = createTemporaryObject(listViewComponent, root, {
                downloadsModel: []
            })
            waitForRendering(view)

            const label = emptyLabel(view)
            verify(!!label)
            verify(label.visible)
            compare(label.text, qsTr("Downloaded files will appear here."))
        }

        function test_empty_placeholder_hidden_when_modelAssignedDirectly() {
            const record = createTemporaryObject(recordComponent, root)
            const view = createTemporaryObject(listViewComponent, root)
            view.downloadsModel = [record]
            waitForRendering(view)

            const label = emptyLabel(view)
            verify(!!label)
            verify(!label.visible)
        }

        function test_empty_placeholder_hidden_when_modelViaCreateObject() {
            // Mirrors BrowserLayout → TabsBookmarksOverviewModal createObject path.
            const record = createTemporaryObject(recordComponent, root)
            const view = listViewComponent.createObject(root, {
                downloadsModel: [record],
                width: 360,
                height: 400
            })
            verify(!!view)
            waitForRendering(view)

            // The bug: Array.isArray fails after createObject conversion.
            // Length must still report non-empty.
            verify(view._count >= 1)

            const label = emptyLabel(view)
            verify(!!label)
            verify(!label.visible)

            view.destroy()
        }

        function test_empty_placeholder_hidden_for_restoredHistoryShapedModel() {
            const record = createTemporaryObject(recordComponent, root, {
                fileName: "from-history.bin",
                state: AbstractWebView.DownloadState.DownloadCompleted
            })
            const view = listViewComponent.createObject(root, {
                downloadsModel: [record],
                width: 360,
                height: 400
            })
            verify(!!view)
            waitForRendering(view)

            verify(!emptyLabel(view).visible)
            view.destroy()
        }

        function test_paused_showsResumeAndCancel_noOptions() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadPaused,
                isPaused: true
            })
            const view = createTemporaryObject(listViewComponent, root, {
                downloadsModel: [record]
            })
            waitForRendering(view)

            const pill = rowPill(view, 0)
            compare(pill.primaryAction, DownloadPill.PrimaryAction.Resume)
            verify(pill.resumeButtonVisible)
            verify(!pill.pauseButtonVisible)
            verify(pill.cancelButtonVisible)
            verify(!pill.optionsButtonVisible)

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

        function test_inProgress_showsPauseAndCancel_noOptions() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadInProgress
            })
            const view = createTemporaryObject(listViewComponent, root, {
                downloadsModel: [record]
            })
            waitForRendering(view)

            const pill = rowPill(view, 0)
            compare(pill.primaryAction, DownloadPill.PrimaryAction.Pause)
            verify(pill.pauseButtonVisible)
            verify(!pill.resumeButtonVisible)
            verify(pill.cancelButtonVisible)
            verify(!pill.optionsButtonVisible)
        }

        function test_paused_primaryButton_resumesRecord() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadPaused,
                isPaused: true
            })
            const view = createTemporaryObject(listViewComponent, root, {
                downloadsModel: [record]
            })
            waitForRendering(view)

            const pill = rowPill(view, 0)
            pill.triggerPrimaryAction()
            compare(record.state, AbstractWebView.DownloadState.DownloadInProgress)
            compare(pill.primaryAction, DownloadPill.PrimaryAction.Pause)
        }

        function test_completed_showsOptions_noInlineTransferControls() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted
            })
            const view = createTemporaryObject(listViewComponent, root, {
                downloadsModel: [record]
            })
            waitForRendering(view)

            const pill = rowPill(view, 0)
            compare(pill.primaryAction, DownloadPill.PrimaryAction.File)
            verify(!pill.pauseButtonVisible)
            verify(!pill.resumeButtonVisible)
            verify(!pill.cancelButtonVisible)
            verify(pill.optionsButtonVisible)
        }

        function test_cancelled_showsOptionsMenu_inList() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCancelled
            })
            const view = createTemporaryObject(listViewComponent, root, {
                downloadsModel: [record]
            })
            waitForRendering(view)

            const pill = rowPill(view, 0)
            compare(pill.primaryAction, DownloadPill.PrimaryAction.Cancelled)
            verify(!pill.cancelButtonVisible)
            verify(pill.optionsButtonVisible, "Cancelled keeps its ⋮ (Retry/Dismiss reachable)")

            const options = findChild(pill, "downloadPillOptionsButton")
            verify(!!options)
            verify(options.visible)
        }

        // Ticket 09: view signals carry the Download Record, not a list index.
        function test_rowClick_emitsTheRecord() {
            const record = createTemporaryObject(recordComponent, root)
            const view = createTemporaryObject(listViewComponent, root, {
                downloadsModel: [record]
            })
            waitForRendering(view)

            let got = null
            view.openDownloadClicked.connect(function (r) { got = r })
            mouseClick(listRow(view, 0))
            compare(got, record)
        }

        function test_optionsClick_emitsRecordAndAnchor() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted
            })
            const view = createTemporaryObject(listViewComponent, root, {
                downloadsModel: [record]
            })
            waitForRendering(view)

            let gotRecord = null
            let gotAnchor = null
            view.optionsClicked.connect(function (r, anchor) {
                gotRecord = r
                gotAnchor = anchor
            })
            const options = findChild(rowPill(view, 0), "downloadPillOptionsButton")
            verify(!!options)
            mouseClick(options)
            compare(gotRecord, record)
            verify(!!gotAnchor, "anchor Item for menu alignment")
        }

        function test_missingFile_struckThrough_inList() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted,
                missingFile: true
            })
            const view = createTemporaryObject(listViewComponent, root, {
                downloadsModel: [record]
            })
            waitForRendering(view)

            const label = findChild(rowPill(view, 0), "downloadPillFileNameLabel")
            verify(!!label)
            verify(label.font.strikeout, "Missing File is struck through in the list")
        }
    }
}
