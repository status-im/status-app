import QtCore
import QtQuick

import StatusQ
import StatusQ.Core
import StatusQ.Popups.Dialog

StatusFolderDialog {
    property string imageSource

    title: qsTranslate("Popups", "Please choose a directory")
    currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)

    onAccepted: {
        SystemUtils.downloadImageByUrl(imageSource, selectedFolder)
        destroy()
    }
    onRejected: destroy()
}
