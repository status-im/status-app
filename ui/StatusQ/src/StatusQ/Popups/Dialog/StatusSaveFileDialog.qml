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

    // the QtQuick.Dialogs object, loaded on the first open()
    readonly property alias dialog: d.dialog

    signal accepted
    signal rejected

    function open() {
        // a dialog takes its window from its nearest parent item
        if (!d.dialog)
            d.dialog = Qt.createComponent(Qt.resolvedUrl("impl/SaveFileDialogImpl.qml")).createObject(root)
        d.dialog.open()
    }

    function close() {
        if (d.dialog)
            d.dialog.close()
    }

    QtObject {
        id: d

        property QtObject dialog: null
    }

    Binding {
        target: d.dialog
        property: "title"
        value: root.title
    }

    Binding {
        target: d.dialog
        property: "defaultSuffix"
        value: root.defaultSuffix
    }

    Binding {
        target: d.dialog
        property: "acceptLabel"
        value: root.acceptLabel
        when: root.acceptLabel !== ""
    }

    Binding {
        target: d.dialog
        property: "selectedFile"
        value: root.selectedFile
        when: root.selectedFile.toString() !== ""
    }

    Connections {
        target: d.dialog

        function onAccepted() {
            root.accepted()
        }

        function onRejected() {
            root.rejected()
        }

        function onSelectedFileChanged() {
            root.selectedFile = d.dialog.selectedFile
        }
    }
}
