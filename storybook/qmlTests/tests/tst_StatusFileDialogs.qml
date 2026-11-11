import QtQuick
import QtTest

import StatusQ.Popups.Dialog

Item {
    id: root

    width: 600
    height: 400

    Component {
        id: fileDialogComponent

        StatusFileDialog {
            title: "Pick"
            nameFilters: ["Images (*.png)"]
            selectMultiple: true
        }
    }

    Component {
        id: folderDialogComponent

        StatusFolderDialog {
            title: "Folder"
        }
    }

    Component {
        id: saveFileDialogComponent

        StatusSaveFileDialog {
            title: "Save"
            defaultSuffix: "png"
            selectedFile: "file:///tmp/image.png"
        }
    }

    TestCase {
        name: "StatusFileDialogs"
        when: windowShown

        function dialogOf(wrapper) {
            return wrapper.dialog
        }

        function test_fileDialogCreatedOnOpen() {
            const wrapper = createTemporaryObject(fileDialogComponent, root)
            verify(!!wrapper)
            compare(dialogOf(wrapper), null)
            compare(wrapper.visible, false)

            wrapper.open()
            const dialog = dialogOf(wrapper)
            verify(!!dialog)
            compare(dialog.title, "Pick")
            compare(dialog.nameFilters, ["Images (*.png)"])
            compare(dialog.fileMode, 1) // FileDialog.OpenFiles
            tryCompare(wrapper, "visible", true)

            wrapper.title = "Pick again"
            compare(dialog.title, "Pick again")
            wrapper.selectMultiple = false
            compare(dialog.fileMode, 0) // FileDialog.OpenFile

            const rejectedSpy = signalSpy.createObject(root, { target: wrapper, signalName: "rejected" })
            dialog.reject()
            compare(rejectedSpy.count, 1)
            tryCompare(wrapper, "visible", false)

            wrapper.open()
            compare(dialogOf(wrapper), dialog)
            wrapper.close()
        }

        function test_folderDialogCreatedOnOpen() {
            const wrapper = createTemporaryObject(folderDialogComponent, root)
            compare(dialogOf(wrapper), null)
            wrapper.open()
            const dialog = dialogOf(wrapper)
            verify(!!dialog)
            compare(dialog.title, "Folder")
            const acceptedSpy = signalSpy.createObject(root, { target: wrapper, signalName: "accepted" })
            dialog.accept()
            compare(acceptedSpy.count, 1)
        }

        function test_saveFileDialogCreatedOnOpen() {
            const wrapper = createTemporaryObject(saveFileDialogComponent, root)
            compare(dialogOf(wrapper), null)
            wrapper.open()
            const dialog = dialogOf(wrapper)
            verify(!!dialog)
            compare(dialog.fileMode, 2) // FileDialog.SaveFile
            compare(dialog.defaultSuffix, "png")
            wrapper.close()
        }
    }

    Component {
        id: signalSpy
        SignalSpy {}
    }
}
