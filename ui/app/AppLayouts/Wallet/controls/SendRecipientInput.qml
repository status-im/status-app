import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Theme

StatusInput {
    id: root

    property bool interactive: true
    property bool checkMarkVisible
    property bool loading
    property string error

    signal clearClicked()
    signal validateInputRequested()

    placeholderText: qsTr("Enter an ENS name or address")
    input.background.color: Theme.palette.indirectColor1
    input.background.border.width: 0
    input.implicitHeight: 64
    rightPadding: 12
    input.clearable: false // custom button below
    input.edit.readOnly: !root.interactive
    multiline: false
    input.edit.textFormat: TextEdit.RichText

    input.rightComponent: RowLayout {
        StatusLoadingIndicator {
            objectName: "loadingIndicator"
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            visible: root.input.edit.length !== 0 && root.loading
        }
        StatusPasteButton {
            id: pasteButton

            objectName: "pasteButton"
            font.weight: Font.Normal
            size: StatusBaseButton.Size.Small
            buttonFocusPolicy: Qt.NoFocus
            visible: root.input.edit.length === 0 && pasteButton.canPaste
            onPasted: (text) => {
                root.input.edit.forceActiveFocus()
                root.text = text // paste plain text
                root.input.edit.cursorPosition = root.input.edit.length
                root.validateInputRequested()
            }
        }
        StatusIconWithTooltip {
            objectName: "errorIcon"
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            icon: "exclamation"
            color: Theme.palette.dangerColor1
            tooltipText: root.error
            visible: !!root.error
        }
        StatusIcon {
            objectName: "checkmarkIcon"
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            icon: "tiny/checkmark"
            color: Theme.palette.primaryColor1
            visible: root.input.edit.length !== 0 && root.checkMarkVisible
        }
        StatusClearButton {
            objectName: "clearButton"
            visible: root.input.edit.length !== 0 && root.interactive
            onClicked: {
                root.input.edit.clear()
                root.clearClicked()
            }
        }
    }

    Connections {
        target: root.input
        function onKeyPressed(event) {
            if (event.matches(StandardKey.Paste)) {
                event.accepted = true
                root.text = ClipboardUtils.text // paste plain text
            }
        }
    }

    Keys.onTabPressed: event.accepted = true
}
