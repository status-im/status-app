import QtQuick

import StatusQ
import StatusQ.Popups
import utils

StatusMenu {
    id: root

    property url url
    property string imageSource
    property bool isGif: root.imageSource.toLowerCase().endsWith(".gif")
    property bool isVideo: root.imageSource.toLowerCase().endsWith(".mp4")

    QtObject {
        id: d
        readonly property bool isUnfurled: (!!root.url && root.url.toString() !== "")
    }

    StatusAction {
        text: root.isGif ? qsTr("Copy GIF") : qsTr("Copy image")
        icon.name: "copy"
        enabled: !!root.imageSource && !root.isVideo
        onTriggered: {
            ClipboardUtils.setImageByUrl(root.imageSource)
        }
    }

    StatusAction {
        text: root.isGif ? qsTr("Download GIF") : root.isVideo ? qsTr("Download video") : qsTr("Download image")
        icon.name: "download"
        enabled: !!root.imageSource
        onTriggered: {
            Global.openDownloadImageDialog(root.imageSource)
        }
    }

    StatusAction {
        text: qsTr("Copy link")
        icon.name: "copy"
        enabled: d.isUnfurled
        onTriggered: ClipboardUtils.setText(root.url.toString())
    }

    StatusAction {
        text: qsTr("Open link")
        icon.name: "browser"
        enabled: d.isUnfurled
        onTriggered: Global.requestOpenLink(root.url.toString())
    }
}
