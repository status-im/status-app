import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import shared.controls

StatusDialog {
    id: root

    required property double slippageValue

    signal slippageSelected(double value)

    objectName: "swapSlippagePopup"

    title: qsTr("Set max price slippage")
    implicitWidth: 480
    standardButtons: Dialog.NoButton

    contentItem: ColumnLayout {
        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            text: qsTr("The swap will revert if the price shifts beyond this percentage.")
            wrapMode: Text.Wrap
            color: Theme.palette.directColor5
        }

        SlippageSelector {
            objectName: "slippageSelector"
            Layout.fillWidth: true

            value: root.slippageValue

            onEdited: newValue => root.slippageSelected(newValue)
            onCommitted: root.close()
        }
    }
}
