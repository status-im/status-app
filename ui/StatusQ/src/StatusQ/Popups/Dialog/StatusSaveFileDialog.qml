pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtCore

import StatusQ.Core.Utils

QObject {
    id: root

    property alias title: dlg.title
    property alias selectedFile: dlg.selectedFile
    property alias acceptLabel: dlg.acceptLabel
    property alias defaultSuffix: dlg.defaultSuffix

    readonly property string picturesShortcut: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    readonly property string documentsLocation: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)

    signal accepted
    signal rejected

    function open() {
        dlg.open()
    }

    function close() {
        dlg.close()
    }

    FileDialog {
        id: dlg

        fileMode: FileDialog.SaveFile

        onAccepted: root.accepted()
        onRejected: root.rejected()
    }
}
