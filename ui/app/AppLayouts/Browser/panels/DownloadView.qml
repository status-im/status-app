import QtQuick

import StatusQ.Core
import StatusQ.Core.Theme

import utils

import AppLayouts.Browser.controls

Rectangle {
    id: root

    property alias downloadsModel: listView.model

    required property var downloadsMenu

    signal openDownloadClicked(bool downloadComplete, int index)

    z: 54
    color: Theme.palette.background

    StatusListView {
        id: listView

        anchors {
            topMargin: Theme.bigPadding
            top: parent.top
            bottom: parent.bottom
            bottomMargin: Theme.bigPadding * 2
            horizontalCenter: parent.horizontalCenter
        }

        width: 624
        spacing: Theme.padding

        delegate: DownloadElement {
            id: downloadElement

            readonly property var downloadItem: downloadsModel.downloads[index]

            width: parent.width
            isPaused: downloadItem?.isPaused ?? false
            isCanceled: downloadItem?.state === WebEngineDownloadRequest.DownloadCancelled ?? false
            primaryText: downloadItem?.downloadFileName ?? ""
            downloadText: {
                if (isCanceled) {
                    return qsTr("Cancelled")
                }
                if (isPaused) {
                    return qsTr("Paused")
                }
                return "%1/%2".arg(Qt.locale().formattedDataSize(downloadItem?.receivedBytes ?? 0, 2, Locale.DataSizeTraditionalFormat)) //e.g. 14.4/109 MB
                              .arg(Qt.locale().formattedDataSize(downloadItem?.totalBytes ?? 0, 2, Locale.DataSizeTraditionalFormat))
            }
            downloadComplete: downloadItem?.state === WebEngineDownloadRequest.DownloadCompleted ?? false
            onItemClicked: {
                openDownloadClicked(downloadComplete, index)
            }
            onOptionsButtonClicked: function(xVal) {
                downloadsMenu.index = index
                downloadsMenu.parent = downloadElement
                downloadsMenu.x = xVal
                downloadsMenu.y = root.y - downloadsMenu.height
                downloadsMenu.open()
            }
        }
    }

    StatusBaseText {
        visible: !listView.count
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        text: qsTr("Downloaded files will appear here.")
        color: Theme.palette.secondaryText
    }
}
