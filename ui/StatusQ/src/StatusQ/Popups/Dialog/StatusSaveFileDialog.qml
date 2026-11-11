import QtQuick
import QtCore

import StatusQ.Core.Utils

QObject {
    id: root

    property string title
    property url selectedFile
    property string acceptLabel
    property string defaultSuffix

    readonly property string picturesShortcut: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
    readonly property string documentsLocation: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)

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

        function ensureDialog() {
            if (!dialog) {
                const props = {
                    title: Qt.binding(() => root.title),
                    defaultSuffix: Qt.binding(() => root.defaultSuffix),
                    fileMode: 2 /* FileDialog.SaveFile */
                }
                if (root.acceptLabel !== "")
                    props.acceptLabel = Qt.binding(() => root.acceptLabel)
                if (root.selectedFile.toString() !== "")
                    props.selectedFile = root.selectedFile
                dialog = Qt.createComponent(Qt.resolvedUrl("impl/FileDialogImpl.qml")).createObject(root, props)
                dialog.accepted.connect(root.accepted)
                dialog.rejected.connect(root.rejected)
                dialog.selectedFileChanged.connect(() => root.selectedFile = dialog.selectedFile)
            }
            return dialog
        }
    }

    onSelectedFileChanged: {
        if (d.dialog && d.dialog.selectedFile.toString() !== root.selectedFile.toString())
            d.dialog.selectedFile = root.selectedFile
    }
}
