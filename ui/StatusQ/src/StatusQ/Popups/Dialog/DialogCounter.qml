pragma Singleton

import QtQml
import QtQuick

QtObject {
    id: root

    property var _openedDialogs: []
    property int openedDialogsCount: 0

    function _isDialogOpened(dialog) {
        if (!dialog)
            return false

        if (typeof dialog.opened !== "undefined")
            return dialog.opened

        return !!dialog.visible
    }

    function _updateCount() {
        root.openedDialogsCount = _openedDialogs.length
    }

    function dialogDestroyed(dialog) {
        if (!dialog)
            return

        const dialogIndex = _openedDialogs.indexOf(dialog)
        if (dialogIndex !== -1)
            _openedDialogs.splice(dialogIndex, 1)
        _updateCount()
    }

    function syncDialog(dialog) {
        if (!dialog)
            return

        const dialogIndex = _openedDialogs.indexOf(dialog)
        if (_isDialogOpened(dialog)) {
            if (dialogIndex === -1)
                _openedDialogs.push(dialog)
            _updateCount()
            return
        }

        if (dialogIndex !== -1) {
            _openedDialogs.splice(dialogIndex, 1)
            _updateCount()
        }
    }

    function getOpenedDialogsCount() {
        return root.openedDialogsCount
    }
}
