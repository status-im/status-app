import QtQuick
import QtQuick.Dialogs
import QtCore

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import MobileUI

QObject {
    id: root

    property alias title: dlg.title
    property alias nameFilters: dlg.nameFilters
    readonly property alias selectedFile: d.resolvedFile
    readonly property alias selectedFiles: d.resolvedFiles
    property bool selectMultiple
    property bool usePhotoLibrary

    property alias modality: dlg.modality
    property alias currentFolder: dlg.currentFolder
    property alias visible: dlg.visible

    property string picturesShortcut: Utils.isIOS ? "assets-library://" :
                            d.standardPictureLocations.length > 1 ? d.standardPictureLocations[1] // [0] is writable, don't need it here, we have StatusSaveFileDialog for that
                                                                  : d.standardPictureLocations.length > 0 ? d.standardPictureLocations[0]
                                                                                                          : ""

    signal accepted
    signal rejected

    function open() {
        if (Utils.isIOS) {
            d.nativeSelectedFiles = []
            d.nativeDialogOpen = true
            if (usePhotoLibrary)
                SystemUtils.openIOSPhotoLibraryPicker(selectMultiple)
            else
                SystemUtils.openIOSDocumentPicker(selectMultiple, nameFilters)
            return
        }

        dlg.open()
    }

    function close() {
        if (Utils.isIOS)
            d.nativeDialogOpen = false
        dlg.close()
    }

    QtObject {
        id: d

        readonly property list<url> standardPictureLocations: StandardPaths.standardLocations(StandardPaths.PicturesLocation)
        property var nativeSelectedFiles: []
        property bool nativeDialogOpen: false

        readonly property url resolvedFile: Utils.isIOS ? resolveFile(nativeSelectedFiles[0]) : resolveFile(dlg.selectedFile)
        readonly property var resolvedFiles: Utils.isIOS ? resolveSelectedFiles(nativeSelectedFiles) : resolveSelectedFiles(dlg.selectedFiles)

        function resolveFile(file) {
            if (!file)
                return ""

            let resolvedLocalFile = UrlUtils.convertUrlToLocalPath(file)
            // This will reserve the access to the file for the duration of the app
            if (Utils.isIOS && !root.usePhotoLibrary && !MobileUI.startAccessingPath(resolvedLocalFile)) {
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

    Connections {
        target: SystemUtils

        function onIosFilePickerAccepted(fileUrls) {
            if (!d.nativeDialogOpen)
                return

            d.nativeDialogOpen = false
            d.nativeSelectedFiles = fileUrls
            root.accepted()
        }

        function onIosFilePickerRejected() {
            if (!d.nativeDialogOpen)
                return

            d.nativeDialogOpen = false
            root.rejected()
        }
    }

    FileDialog {
        id: dlg

        fileMode: selectMultiple ? FileDialog.OpenFiles : FileDialog.OpenFile

        onAccepted: root.accepted()
        onRejected: root.rejected()
    }
}
