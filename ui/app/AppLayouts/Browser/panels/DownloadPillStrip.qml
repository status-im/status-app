import QtQuick
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import AppLayouts.Browser.controls

/**
 * Download Pill strip (session-only — never fed from Download History).
 * Mobile: under the address bar. Desktop: window footer (replaces DownloadBar).
 * One pill → full width; multiple → min 128 / max 236 (same rules as tabs).
 */
Rectangle {
    id: root

    property var downloadsModel: []
    // Optional: DownloadsStore.elideFileName — middle-elide base, keep extension.
    property var elideFileNameFn: null

    readonly property int minPillWidth: 128
    readonly property int maxPillWidth: 236

    signal openDownloadClicked(int index)
    signal optionsClicked(int index, Item anchor, real xVal)
    signal close()

    color: Theme.palette.background
    implicitHeight: 52
    border.width: 1
    border.color: Theme.palette.border

    readonly property int _count: Array.isArray(downloadsModel) ? downloadsModel.length : 0
    readonly property bool _single: _count === 1

    function pillWidthForCount(availableWidth, count) {
        if (count <= 0)
            return 0
        if (count === 1)
            return availableWidth
        const spacing = Theme.smallPadding
        const totalSpacing = spacing * Math.max(0, count - 1)
        const raw = (availableWidth - totalSpacing) / count
        return Math.min(maxPillWidth, Math.max(minPillWidth, raw))
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.smallPadding
        anchors.rightMargin: Theme.halfPadding
        spacing: Theme.smallPadding

        ListView {
            id: listView
            objectName: "downloadPillListView"

            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            clip: true
            spacing: Theme.smallPadding
            boundsBehavior: Flickable.StopAtBounds
            model: root.downloadsModel

            delegate: DownloadPill {
                id: pill

                readonly property var downloadItem: modelData
                readonly property int pillIndex: index

                download: downloadItem
                elideFileNameFn: root.elideFileNameFn
                fillWidth: root._single
                width: {
                    const available = Math.max(0, listView.width)
                    if (root._single)
                        return available
                    return root.pillWidthForCount(available, root._count)
                }
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined

                onItemClicked: root.openDownloadClicked(pillIndex)
                onOptionsButtonClicked: function (xVal) {
                    root.optionsClicked(pillIndex, pill, xVal)
                }
            }

            onCountChanged: positionViewAtEnd()
            Component.onCompleted: positionViewAtEnd()
        }

        StatusFlatRoundButton {
            id: closeBtn
            objectName: "downloadPillStripClose"
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter
            icon.name: "close"
            type: StatusFlatRoundButton.Type.Quaternary
            onClicked: root.close()
        }
    }
}
