import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Core.Utils

StatusInput {
    id: root

    property bool interactive: true
    property bool checkMarkVisible
    property bool loading

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
        StatusButton {
            objectName: "pasteButton"
            font.weight: Font.Normal
            borderColor: Theme.palette.primaryColor1
            borderWidth: 1
            size: StatusBaseButton.Size.Tiny
            text: qsTr("Paste")
            // On iOS, reading canPaste triggers the system "paste from..." prompt.
            // Show the paste button whenever the field is empty; the tap reads.
            visible: root.input.edit.length === 0 && (Utils.isIOS || root.input.edit.canPaste)
            focusPolicy: Qt.NoFocus
            onClicked: {
                root.input.edit.forceActiveFocus()
                root.text = ClipboardUtils.text // paste plain text
                root.input.edit.cursorPosition = root.input.edit.length
                root.validateInputRequested()
            }
        }
        StatusIcon {
            objectName: "checkmarkIcon"
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            icon: "tiny/checkmark"
            color: Theme.palette.primaryColor1
            visible: root.checkMarkVisible
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

    Keys.onTabPressed: (event) => {
                           event.accepted = true
                       }
    Keys.onReleased: (event) => {
                         event.accepted = true
                         root.validateInputRequested()
                     }
}
