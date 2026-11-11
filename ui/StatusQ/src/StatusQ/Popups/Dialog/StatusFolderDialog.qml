import QtQuick

import StatusQ
import StatusQ.Core.Utils
import MobileUI

QObject {
    id: root

    property string title
    readonly property alias selectedFolder: d.resolvedFolder
    property int modality: Qt.WindowModal
    property url currentFolder

    // the QtQuick.Dialogs object, created on the first open()
    readonly property alias dialog: d.dialog

    signal accepted
    signal rejected

    function open() {
        d.ensureDialog().open()
    }

    function close() {
        d.dialog?.close()
    }

    QtObject {
        id: d
        property QtObject dialog: null
        property url resolvedFolder: d.resolveFolder(dialog?.selectedFolder ?? "")

        function ensureDialog() {
            if (!dialog) {
                const props = {
                    title: Qt.binding(() => root.title)
                }
                if (root.currentFolder.toString() !== "")
                    props.currentFolder = root.currentFolder
                dialog = Qt.createComponent(Qt.resolvedUrl("impl/FolderDialogImpl.qml")).createObject(root, props)
                // enum properties reject Qt.binding() as an initial property
                dialog.modality = Qt.binding(() => root.modality)
                dialog.accepted.connect(root.accepted)
                dialog.rejected.connect(root.rejected)
                dialog.currentFolderChanged.connect(() => root.currentFolder = dialog.currentFolder)
            }
            return dialog
        }

        function resolveFolder(folder) {
            let resolvedFolder = folder;
            if (Utils.isIOS) {
                //Convert from `file://` to local path
                resolvedFolder = UrlUtils.convertUrlToLocalPath(folder)
                // This will reserve the access to the folder for the duration of the app
                const success = MobileUI.startAccessingPath(resolvedFolder)
                if (!success) {
                    console.warn("StatusFolderDialog failed to start access for selected folder")
                }
            }
            return resolvedFolder;
        }
    }

    onCurrentFolderChanged: {
        if (d.dialog && d.dialog.currentFolder.toString() !== root.currentFolder.toString())
            d.dialog.currentFolder = root.currentFolder
    }
}
