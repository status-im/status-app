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

    // the QtQuick.Dialogs object, loaded on the first open()
    readonly property alias dialog: d.dialog

    signal accepted
    signal rejected

    function open() {
        // a dialog takes its window from its nearest parent item
        if (!d.dialog)
            d.dialog = Qt.createComponent(Qt.resolvedUrl("impl/FolderDialogImpl.qml")).createObject(root)
        d.dialog.open()
    }

    function close() {
        if (d.dialog)
            d.dialog.close()
    }

    QtObject {
        id: d

        property QtObject dialog: null
        property url resolvedFolder: d.resolveFolder(d.dialog?.selectedFolder ?? "")

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

    Binding {
        target: d.dialog
        property: "title"
        value: root.title
    }

    Binding {
        target: d.dialog
        property: "modality"
        value: root.modality
    }

    Binding {
        target: d.dialog
        property: "currentFolder"
        value: root.currentFolder
        when: root.currentFolder.toString() !== ""
    }

    Connections {
        target: d.dialog

        function onAccepted() {
            root.accepted()
        }

        function onRejected() {
            root.rejected()
        }

        function onCurrentFolderChanged() {
            root.currentFolder = d.dialog.currentFolder
        }
    }
}
