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

    StatusMenu {
        id: contextMenu

        hideDisabledItems: false
        popupType: Utils.isIOS ? Popup.Native : Popup.Item

        StatusAction {
            text: qsTr("Cut")
            enabled: !noSelection
            onTriggered: root.cut()
        }
        StatusAction {
            text: qsTr("Copy")
            enabled: !noSelection
            onTriggered: root.copy()
        }
        StatusAction {
            text: qsTr("Paste")
            enabled: root.canPaste
            onTriggered: root.paste()
        }
        StatusMenuSeparator {}
        StatusAction {
            text: qsTr("Select All")
            enabled: !noSelection
            onTriggered: root.selectAll()
        }
    }

    ContextMenu.menu: Utils.isAndroid ? null : contextMenu
}
