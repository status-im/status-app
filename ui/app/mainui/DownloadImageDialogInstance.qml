import QtCore
import QtQuick

import StatusQ
import StatusQ.Popups.Dialog

StatusFolderDialog {
    property string imageSource

    title: qsTr("Please choose a directory")
    currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)

    onAccepted: {
        SystemUtils.downloadImageByUrl(imageSource, selectedFolder)
        destroy()
    }
    onRejected: destroy()
}
