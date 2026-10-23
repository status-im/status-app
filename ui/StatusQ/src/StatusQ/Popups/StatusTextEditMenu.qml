import QtQuick
import QtQuick.Controls
import QtQml.Models

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

    // spellcheck related
    property bool spellingTarget: false
    property bool spellingPending: false
    property var spellingSuggestions: []

    signal cutRequested()
    signal copyRequested()
    signal pasteRequested()
    signal selectAllRequested()
    signal spellingSuggestionRequested(string replacement)

    hideDisabledItems: false
    visualizeShortcuts: true
    itemVerticalPadding: 12

    Instantiator {
        model: root.spellingSuggestions
        delegate: StatusAction {
            required property string modelData
            text: modelData
            objectName: "spellingSuggestion_" + modelData
            onTriggered: {
                const menu = root
                menu.spellingSuggestionRequested(modelData)
                menu.close()
            }
        }
        onObjectAdded: (index, object) => root.insertAction(index, object)
        onObjectRemoved: (index, object) => root.removeAction(object)
    }
    StatusMenuItem {
        objectName: "spellingSuggestionsPlaceholder"
        visible: root.spellingTarget && root.spellingSuggestions.length === 0
        height: visible ? implicitHeight : 0
        enabled: false
        text: root.spellingPending ? qsTr("Checking spelling...") : qsTr("No suggestions")
    }
    StatusMenuSeparator {
        visible: root.spellingTarget
        height: visible ? implicitHeight : 0
    }

    StatusAction {
        text: qsTr("Cut")
        enabled: root.canCut
        shortcut: StandardKey.Cut
        onTriggered: root.cutRequested()
    }
    StatusAction {
        text: qsTr("Copy")
        enabled: root.canCopy
        shortcut: StandardKey.Copy
        onTriggered: root.copyRequested()
    }
    StatusAction {
        text: qsTr("Paste")
        enabled: root.canPaste
        shortcut: StandardKey.Paste
        onTriggered: root.pasteRequested()
    }
    StatusMenuSeparator {}
    StatusAction {
        text: qsTr("Select All")
        enabled: root.canSelectAll
        shortcut: StandardKey.SelectAll
        onTriggered: root.selectAllRequested()
    }
}
