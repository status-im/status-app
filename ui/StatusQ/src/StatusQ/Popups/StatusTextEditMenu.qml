import QtQuick
import QtQuick.Controls

import StatusQ.Core.Utils
import StatusQ.Popups

// Standard text-editing context menu (Cut / Copy / Paste / Select All) for text
// inputs. It owns only the menu items and their enablement; the editor wires the
// *Requested signals to its own cut/copy/paste/selectAll routines and decides how
// (and whether) to attach it (e.g. via the ContextMenu.menu attached property).
StatusMenu {
    id: root

    // There is a selection to cut — enables Cut.
    property bool canCut: false

    // There is a selection to copy — enables Copy.
    property bool canCopy: false

    // Something is available to paste — enables Paste. The caller passes its own
    // clipboard check; the menu deliberately does not read the clipboard itself
    // (on iOS a mere read triggers the system "paste from…" prompt).
    property bool canPaste: true

    // There is content to select — enables Select All.
    property bool canSelectAll: true

    signal cutRequested()
    signal copyRequested()
    signal pasteRequested()
    signal selectAllRequested()

    hideDisabledItems: false

    StatusAction {
        text: qsTr("Cut")
        enabled: root.canCut
        onTriggered: root.cutRequested()
    }
    StatusAction {
        text: qsTr("Copy")
        enabled: root.canCopy
        onTriggered: root.copyRequested()
    }
    StatusAction {
        text: qsTr("Paste")
        enabled: root.canPaste
        onTriggered: root.pasteRequested()
    }
    StatusMenuSeparator {}
    StatusAction {
        text: qsTr("Select All")
        enabled: root.canSelectAll
        onTriggered: root.selectAllRequested()
    }
}
