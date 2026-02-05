import QtQuick
import QtQuick.Dialogs
import QtCore

import StatusQ
import StatusQ.Core.Utils
import MobileUI

QObject {
    id: root

    property alias title: dlg.title
    property alias nameFilters: dlg.nameFilters
    readonly property alias selectedFile: d.resolvedFile
    readonly property alias selectedFiles: d.resolvedFiles
    property bool selectMultiple

    property alias modality: dlg.modality
    property alias currentFolder: dlg.currentFolder

    property string picturesShortcut: Utils.isIOS ? "assets-library://" :
                            d.standardPictureLocations.length > 1 ? d.standardPictureLocations[1] // [0] is writable, don't need it here, we have StatusSaveFileDialog for that
                                                                  : d.standardPictureLocations.length > 0 ? d.standardPictureLocations[0]
                                                                                                          : ""

    signal accepted
    signal rejected

    function open() {
        dlg.open()
    }

    function close() {
        dlg.close()
    }

    MobileUI {
        id: mobileUI
    }

    QtObject {
        id: d

        readonly property list<url> standardPictureLocations: StandardPaths.standardLocations(StandardPaths.PicturesLocation)

        readonly property url resolvedFile: resolveFile(dlg.selectedFile)
        readonly property var resolvedFiles: resolveSelectedFiles(dlg.selectedFiles)

        function resolveFile(file) {
            if (!file)
                return ""

            let resolvedLocalFile = UrlUtils.convertUrlToLocalPath(file)
            // This will reserve the access to the file for the duration of the app
            if (Utils.isIOS && !mobileUI.startAccessingPath(resolvedLocalFile)) {
                console.warn("StatusFileDialog failed to start access for selected file")
            }
            if (!resolvedLocalFile.startsWith("file:"))
                resolvedLocalFile = "file:" + resolvedLocalFile
            return resolvedLocalFile
        }

        function resolveSelectedFiles(selectedFiles) {
            if (selectedFiles.length === 0)
                return []

            return selectedFiles.map(file => d.resolveFile(file)).filter(file => !!file)
        }
    }

    FileDialog {
        id: dlg

        fileMode: selectMultiple ? FileDialog.OpenFiles : FileDialog.OpenFile

        onAccepted: root.accepted()
        onRejected: root.rejected()
    }
}
