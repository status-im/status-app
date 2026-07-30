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

            const row = listRow(view, 0)
            compare(row.primaryAction, DownloadPill.PrimaryAction.Resume)
            verify(row.resumeButtonVisible)
            verify(!row.pauseButtonVisible)
            verify(row.cancelButtonVisible)
            verify(!row.optionsButtonVisible)

            const primary = findChild(row, "downloadsListPrimaryButton")
            verify(!!primary)
            verify(primary.visible)
            compare(primary.icon.name, "play")

            const cancel = findChild(row, "downloadsListCancelButton")
            verify(!!cancel)
            verify(cancel.visible)

            const options = findChild(row, "downloadsListOptionsButton")
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

            const row = listRow(view, 0)
            compare(row.primaryAction, DownloadPill.PrimaryAction.Pause)
            verify(row.pauseButtonVisible)
            verify(!row.resumeButtonVisible)
            verify(row.cancelButtonVisible)
            verify(!row.optionsButtonVisible)
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

            const row = listRow(view, 0)
            row.triggerPrimaryAction()
            compare(record.state, AbstractWebView.DownloadState.DownloadInProgress)
            compare(row.primaryAction, DownloadPill.PrimaryAction.Pause)
        }

        function test_completed_showsOptions_noInlineTransferControls() {
            const record = createTemporaryObject(recordComponent, root, {
                state: AbstractWebView.DownloadState.DownloadCompleted
            })
            const view = createTemporaryObject(listViewComponent, root, {
                downloadsModel: [record]
            })
            waitForRendering(view)

            const row = listRow(view, 0)
            compare(row.primaryAction, DownloadPill.PrimaryAction.File)
            verify(!row.pauseButtonVisible)
            verify(!row.resumeButtonVisible)
            verify(!row.cancelButtonVisible)
            verify(row.optionsButtonVisible)
        }
    }
}
