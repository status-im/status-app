import QtQuick
import QtCore

import StatusQ
import StatusQ.Core
import StatusQ.Core.Utils
import MobileUI

QObject {
    id: root

    property string title
    property list<string> nameFilters
    readonly property alias selectedFile: d.resolvedFile
    readonly property alias selectedFiles: d.resolvedFiles
    property bool selectMultiple
    property bool usePhotoLibrary

    property int modality: Qt.WindowModal
    property url currentFolder
    readonly property bool visible: d.dialog?.visible ?? false

    readonly property string picturesShortcut: Utils.isIOS ? "assets-library://" :
                            d.standardPictureLocations.length > 1 ? d.standardPictureLocations[1] // [0] is writable, don't need it here, we have StatusSaveFileDialog for that
                                                                  : d.standardPictureLocations.length > 0 ? d.standardPictureLocations[0]
                                                                                                          : ""

    // the QtQuick.Dialogs object, created on the first open()
    readonly property alias dialog: d.dialog

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

        d.ensureDialog().open()
    }

    function close() {
        if (Utils.isIOS)
            d.nativeDialogOpen = false
        d.dialog?.close()
    }

    QtObject {
        id: d

        property QtObject dialog: null

        function ensureDialog() {
            if (!dialog) {
                const props = {
                    title: Qt.binding(() => root.title),
                    nameFilters: Qt.binding(() => root.nameFilters)
                }
                if (root.currentFolder.toString() !== "")
                    props.currentFolder = root.currentFolder
                dialog = Qt.createComponent(Qt.resolvedUrl("impl/FileDialogImpl.qml")).createObject(root, props)
                // enum properties reject Qt.binding() as an initial property
                dialog.modality = Qt.binding(() => root.modality)
                dialog.fileMode = Qt.binding(() => root.selectMultiple ? 1 /* FileDialog.OpenFiles */
                                                                       : 0 /* FileDialog.OpenFile */)
                dialog.accepted.connect(root.accepted)
                dialog.rejected.connect(root.rejected)
                dialog.currentFolderChanged.connect(() => root.currentFolder = dialog.currentFolder)
            }
            return dialog
        }

        readonly property list<url> standardPictureLocations: StandardPaths.standardLocations(StandardPaths.PicturesLocation)
        property var nativeSelectedFiles: []
        property bool nativeDialogOpen: false

        readonly property url resolvedFile: Utils.isIOS ? resolveFile(nativeSelectedFiles[0]) : resolveFile(d.dialog?.selectedFile ?? "")
        readonly property var resolvedFiles: Utils.isIOS ? resolveSelectedFiles(nativeSelectedFiles) : resolveSelectedFiles(d.dialog?.selectedFiles ?? [])

        function resolveFile(file) {
            if (!file)
                return ""

            if (!Utils.isMobile) // no need to do anything, just return the URL from the FileDialog as-is
                return file

            // on Android, this copies the virtual file to a physical TMP file, and returns path to it
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

    onCurrentFolderChanged: {
        if (d.dialog && d.dialog.currentFolder.toString() !== root.currentFolder.toString())
            d.dialog.currentFolder = root.currentFolder
    }
}
