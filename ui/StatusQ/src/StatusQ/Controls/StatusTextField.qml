import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Universal

import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

TextField {
    id: root
    Accessible.name: Utils.formatAccessibleName(placeholderText, objectName)

    font.family: Fonts.baseFont.family
    font.pixelSize: Theme.primaryTextFontSize
    color: readOnly ? Theme.palette.baseColor1 : Theme.palette.directColor1
    selectByMouse: true
    selectedTextColor: Theme.palette.directColor1
    selectionColor: Theme.palette.primaryColor2
    placeholderTextColor: Theme.palette.baseColor1

    opacity: enabled ? 1 : ThemeUtils.disabledOpacity

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
}
