import QtQuick
import QtQml
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Utils as SQUtils
import StatusQ.Popups
import StatusQ.Controls
import StatusQ.Components
import StatusQ.Core.Theme

import AppLayouts.Wallet.services.dapps.types

ColumnLayout {
    id: root

    readonly property bool valid: input.valid && input.text.length > 0
    readonly property alias text: input.text
    property alias pending: input.pending
    property int errorState: Pairing.errors.notChecked

    // Computed error message - separate from valid to avoid binding loop
    readonly property string computedErrorText: {
        if (input.text.length === 0) return ""
        switch (root.errorState) {
        case Pairing.errors.tooCool: return qsTr("WalletConnect URI too cool")
        case Pairing.errors.invalidUri: return qsTr("WalletConnect URI invalid")
        case Pairing.errors.alreadyUsed: return qsTr("WalletConnect URI already used")
        case Pairing.errors.expired: return qsTr("WalletConnect URI has expired")
        case Pairing.errors.unsupportedNetwork: return qsTr("dApp is requesting to connect on an unsupported network")
        case Pairing.errors.unknownError: return qsTr("Unexpected error occurred. Try again.")
        default: return ""
        }
    }

    StatusBaseInput {
        id: input

        Component.onCompleted: {
            forceActiveFocus()
        }

        Layout.fillWidth: true
        Layout.preferredHeight: 132

        placeholderText: qsTr("Paste URI")
        verticalAlignment: TextInput.AlignTop

        valid: root.computedErrorText.length === 0

        rightComponent: Item {
            width: pasteButton.implicitWidth
            height: pasteButton.implicitHeight

            readonly property bool showIcon: input.valid && input.text.length > 0

            StatusLoadingIndicator {
                anchors.centerIn: parent
                color: StatusColors.getColor("blue")
                visible: showIcon && input.pending
            }

            StatusIcon {
                anchors.centerIn: parent

                icon: "tiny/tiny-checkmark"
                color: Theme.palette.green
                visible: showIcon && !input.pending
            }

            StatusButton {
                id: pasteButton

                text: qsTr("Paste")

                size: StatusBaseButton.Size.Small

                visible: !showIcon

                borderWidth: enabled ? 1 : 0
                borderColor: textColor

                enabled: input.edit.canPaste

                onClicked: {
                    input.edit.paste()
                    input.edit.focus = !SQUtils.Utils.isMobile
                }
            }
        }

        multiline: true
    }

    StatusBaseText {
        id: errorText

        text: root.computedErrorText
        visible: text.length > 0

        Layout.alignment: Qt.AlignRight

        color: Theme.palette.dangerColor1
    }
}
