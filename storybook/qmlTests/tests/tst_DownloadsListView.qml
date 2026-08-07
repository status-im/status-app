import QtQuick
import QtTest

import AppLayouts.Browser.adapters
import AppLayouts.Browser.controls
import AppLayouts.Browser.panels

/**
 * DownloadsListView: empty line only at zero Records.
 * Model may arrive via object construction (BrowserLayout → createObject), where a
 * JS array is converted and no longer reports as Array — count must use .length.
 * Rows render through the shared DownloadPill delegate; its per-state controls
 * matrix is asserted in tst_DownloadPill.
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

        // Rows render through the shared DownloadPill delegate.
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

        // The per-state controls matrix lives in the shared DownloadPill and is
        // asserted once, in tst_DownloadPill. The list keeps one shared-delegate
        // case (below) plus its own concerns: empty state and record signals.
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

        // View signals carry the Download Record, not a list index.
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
            // The ⋮ button itself, so the menu can parent to it and follow the row.
            compare(gotAnchor, options)
        }

        // A context menu over a scrolling list should not linger — the host
        // must be told to close it.
        function test_scroll_emitsScrolled() {
            const records = []
            for (let i = 0; i < 20; ++i)
                records.push(createTemporaryObject(recordComponent, root, {
                    fileName: "file-%1.bin".arg(i)
                }))
            const view = createTemporaryObject(listViewComponent, root, {
                downloadsModel: records
            })
            waitForRendering(view)

            let scrolled = 0
            view.scrolled.connect(function () { scrolled += 1 })

            const list = findChild(view, "downloadsListView")
            verify(!!list)
            list.flick(0, -800)
            tryVerify(() => scrolled > 0, 1000, "scrolling must ask the host to close the menu")
        }
    }
}
