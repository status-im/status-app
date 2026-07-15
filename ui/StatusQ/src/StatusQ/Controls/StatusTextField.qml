import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils
import StatusQ.Popups

TextField {
    id: root

    property bool showBackground: true

    Accessible.name: Utils.formatAccessibleName(placeholderText, objectName)

    font.family: Fonts.baseFont.family
    font.pixelSize: Theme.primaryTextFontSize
    color: readOnly ? Theme.palette.baseColor1 : Theme.palette.directColor1
    selectByMouse: true
    selectedTextColor: Theme.palette.directColor1
    selectionColor: Theme.palette.primaryColor2
    placeholderTextColor: Theme.palette.baseColor1
    verticalAlignment: Text.AlignVCenter
    opacity: enabled ? 1 : ThemeUtils.disabledOpacity

    leftPadding: Theme.defaultPadding
    rightPadding: Theme.defaultPadding
    topPadding: Theme.defaultHalfPadding
    bottomPadding: Theme.defaultHalfPadding

    HoverHandler {
        id: hoverHandler
        enabled: root.enabled
        // Build the edit context menu on first hover (see contextMenuLoader).
        onHoveredChanged: if (hovered && !Utils.isAndroid) contextMenuLoader.active = true
    }

    background: Rectangle {
        implicitHeight: 44
        color: root.showBackground ? Theme.palette.statusAppNavBar.backgroundColor : "transparent"
        radius: Theme.radius

        border.width: 1
        border.color: {
            if (!root.showBackground)
                return "transparent"
            if (root.cursorVisible)
                return Theme.palette.primaryColor1
            return hoverHandler.hovered ? Theme.palette.primaryColor2 : Theme.palette.primaryColor3
        }
    }

    cursorDelegate: StatusCursorDelegate {
        cursorVisible: root.cursorVisible
    }

    // selectedText is not notified correctly when selection is cleared on Android.
    // Similarly cursorVisible is not updated properly to be visible when text is
    // deselected. As a workaround selection is tracked via selectionStart
    // and selectionEnd and deselect is called manually to update cursor visibility.
    readonly property bool noSelection: selectionStart === selectionEnd

    onNoSelectionChanged: {
        if (noSelection && activeFocus)
            deselect()
    }

    // The edit context menu (Cut/Copy/Paste/Select All) is only reachable via a
    // right-click or long-press, both always preceded by the pointer entering the
    // field or the field gaining focus. Building it eagerly per field is a
    // dominant instantiation cost (a full StatusMenu with materialised items),
    // paid even when the field is never interacted with — and on Android it is not
    // even attached (see below). So build it lazily on first interaction, never on
    // Android. The menu is null until then; a right-click cannot happen before the
    // triggering hover/focus, so the menu is always present by the time it opens.
    onActiveFocusChanged: if (activeFocus && !Utils.isAndroid) contextMenuLoader.active = true

    Loader {
        id: contextMenuLoader
        active: false
        sourceComponent: StatusMenu {
            hideDisabledItems: false
            popupType: Utils.isIOS ? Popup.Native : Popup.Item

            StatusAction {
                text: qsTr("Cut")
                enabled: !root.noSelection
                onTriggered: root.cut()
            }
            StatusAction {
                text: qsTr("Copy")
                enabled: !root.noSelection
                onTriggered: root.copy()
            }
            StatusAction {
                text: qsTr("Paste")
                // On iOS, never read the clipboard for UI enablement: reading
                // canPaste touches UIPasteboard and triggers the system
                // "paste from..." prompt. Keep Paste always enabled there and let
                // the actual paste() be the only (user-initiated) clipboard read.
                // On desktop, reading canPaste is free and keeps the disabled state.
                enabled: Utils.isIOS || root.canPaste
                onTriggered: root.paste()
            }
            StatusMenuSeparator {}
            StatusAction {
                text: qsTr("Select All")
                enabled: !root.noSelection
                onTriggered: root.selectAll()
            }
        }
    }

    ContextMenu.menu: contextMenuLoader.item
}
