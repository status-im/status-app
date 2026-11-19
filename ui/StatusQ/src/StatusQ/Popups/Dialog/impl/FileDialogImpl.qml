import QtQuick.Dialogs

// Loaded by StatusFileDialog on the first open()
FileDialog {
    property bool selectMultiple: false

    fileMode: selectMultiple ? FileDialog.OpenFiles : FileDialog.OpenFile
}
