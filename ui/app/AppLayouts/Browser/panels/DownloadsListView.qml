import QtQuick
import QtQuick.Controls

import StatusQ
import StatusQ.Core
import StatusQ.Core.Theme

import AppLayouts.Browser.controls

/**
 * Downloads List for the tabs/bookmarks overview.
 * Newest Records first. Each row is the shared DownloadPill delegate rendered
 * flat — the state-to-controls matrix, wording, eliding and Missing File
 * presentation all live in the pill.
 */
Item {
    id: root

    property var downloadsModel: []

    /// Both signals carry the Download Record — the one identity vocabulary
    /// for a download; no index space to translate.
    signal openDownloadClicked(var record)
    /// anchor is the row's ⋮ button — the menu parents to it.
    signal optionsClicked(var record, Item anchor)
    /// A context menu over a scrolling list should not linger, attached or
    /// not — the host closes it when the list starts moving.
    signal scrolled()

    // Length, not Array.isArray: createObject converts JS arrays so isArray fails
    // while .length still reports Records.
    readonly property int _count: downloadsModel && downloadsModel.length !== undefined
                                  ? downloadsModel.length : 0

    StatusListView {
        id: listView
        objectName: "downloadsListView"
        anchors.fill: parent
        model: root.downloadsModel
        spacing: Theme.halfPadding
        onMovementStarted: root.scrolled()

        delegate: ItemDelegate {
            id: row
            required property var modelData
            required property int index

            width: ListView.view.width
            height: 56
            padding: Theme.halfPadding

            background: Rectangle {
                radius: Theme.radius
                color: row.hovered ? Theme.palette.primaryColor3 : StatusColors.transparent
            }

            contentItem: DownloadPill {
                id: pill
                download: row.modelData

                // Flat-row chrome: the surrounding delegate owns hover and click.
                interactive: false
                pillColor: StatusColors.transparent
                leadingSlotSize: 32
                contentSpacing: Theme.padding
                leadingMargin: 0
                trailingMargin: 0
                nameFontSize: Theme.fontSize(14)
                statusFontSize: Theme.fontSize(12)

                // The pill's own Record, not row.modelData: a contentItem is
                // reparented out of the delegate's scope while the menu is open,
                // and a recycled row can already carry the next Record by then.
                onOptionsButtonClicked: anchor => root.optionsClicked(pill.download, anchor)
            }

            onClicked: root.openDownloadClicked(row.modelData)

            HoverHandler {
                cursorShape: hovered ? Qt.PointingHandCursor : undefined
            }
        }
    }

    StatusBaseText {
        objectName: "downloadsListEmptyLabel"
        visible: root._count === 0
        anchors.centerIn: parent
        text: qsTr("Downloaded files will appear here.")
        color: Theme.palette.secondaryText
    }
}
