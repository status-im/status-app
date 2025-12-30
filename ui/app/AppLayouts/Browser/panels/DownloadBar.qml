import QtQuick
import QtQuick.Layouts
import QtWebEngine

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

import utils

import AppLayouts.Browser.controls

Rectangle {
    id: root

    property var downloadsModel
    property var downloadsMenu

    signal openDownloadClicked(bool downloadComplete, int index)
    signal addNewDownloadTab()
    signal close()

    color: Theme.palette.background
    implicitHeight: 56
    border.width: 1
    border.color: Theme.palette.border

    RowLayout {
        anchors.fill: parent

        StatusListView {
            id: listView

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: currentItem ? currentItem.height : 0

            orientation: ListView.Horizontal
            model: downloadsModel
            spacing: Theme.smallPadding
            delegate: DownloadElement {
                id: downloadElement

                readonly property var downloadItem: downloadsModel.downloads[index]

                isPaused: downloadItem?.isPaused ?? false
                isCanceled: downloadItem?.state === WebEngineDownloadRequest.DownloadCancelled ?? false
                downloadComplete: downloadItem?.state === WebEngineDownloadRequest.DownloadCompleted ?? false
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
                onItemClicked: {
                    openDownloadClicked(downloadComplete, index)
                }
                onOptionsButtonClicked: function (xVal) {
                    downloadsMenu.index = index
                    downloadsMenu.parent = downloadElement
                    downloadsMenu.x = xVal + 20
                    downloadsMenu.y = -downloadsMenu.height
                    downloadsMenu.open()
                }
            }

            onCountChanged: positionViewAtEnd()
            Component.onCompleted: positionViewAtEnd()
        }

        StatusButton {
            id: showAllBtn

            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.rightMargin: Theme.padding

            size: StatusBaseButton.Size.Small
            text: qsTr("Show All")
            onClicked: {
                addNewDownloadTab()
            }
        }

        StatusFlatRoundButton {
            id: closeBtn

            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.rightMargin: Theme.smallPadding

            icon.name: "close"
            type: StatusFlatRoundButton.Type.Quaternary
            onClicked: root.close()
        }
    }
}
