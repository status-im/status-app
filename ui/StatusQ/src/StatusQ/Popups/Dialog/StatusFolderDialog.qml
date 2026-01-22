import QtQuick
import QtQuick.Dialogs

import StatusQ
import StatusQ.Core.Utils
import MobileUI

QObject {
    id: root

    property alias title: dlg.title
    readonly property alias selectedFolder: d.resolvedFolder
    property alias modality: dlg.modality
    property alias currentFolder: dlg.currentFolder

    signal accepted
    signal rejected

    function open() {
        dlg.open()
    }

    function close() {
        dlg.close()
    }

    QtObject {
        id: d
        property url resolvedFolder: d.resolveFolder(dlg.selectedFolder)

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

    FolderDialog {
        id: dlg

        onAccepted: root.accepted()
        onRejected: root.rejected()
    }
}
