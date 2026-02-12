import QtQuick
import QtQuick.Controls
import QtWebEngine

import StatusQ.Popups

import AppLayouts.Browser.stores as BrowserStores

StatusMenu {
    id: root

    required property BrowserStores.DownloadsStore downloadsStore

    property int index: -1
    property var download: root.downloadsStore.getDownload(index)

    readonly property bool downloadCancelled: download?.state === WebEngineDownloadRequest.DownloadCancelled ?? false
    readonly property bool downloadComplete: download?.state === WebEngineDownloadRequest.DownloadCompleted ?? false

    StatusAction {
        enabled: downloadComplete
        icon.name: "file"
        text: qsTr("Open")
        onTriggered: root.downloadsStore.openFile(index)
    }
    StatusAction {
        icon.name: "show"
        text: qsTr("Show in folder")
        onTriggered: root.downloadsStore.openDirectory(index)
    }
    StatusAction {
        enabled: !downloadComplete && !!download && !download.isPaused && !downloadCancelled
        icon.name: "pause"
        text: qsTr("Pause")
        onTriggered: {
            download.pause()
        }
    }
    StatusAction {
        enabled: !downloadComplete && !!download && download.isPaused && !downloadCancelled
        icon.name: "play"
        text: qsTr("Resume")
        onTriggered: {
            download.resume()
        }
    }
    StatusMenuSeparator {
        visible: !downloadComplete && !downloadCancelled
    }
    StatusAction {
        enabled: !downloadComplete && !downloadCancelled
        type: StatusAction.Type.Danger
        icon.name: "block-icon"
        icon.width: 13
        icon.height: 13
        text: qsTr("Cancel")
        onTriggered: {
            download.cancel()
        }
    }
}
