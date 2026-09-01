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

    QtObject {
        id: d

        readonly property var presets: [0.1, 0.5, 1]
        readonly property double valueTooHighThreshold: 5
    }

    Component.onCompleted: {
        if (d.presets.includes(root.slippageValue))
            customInput.clear()
        else
            customInput.value = root.slippageValue
    }

    contentItem: ColumnLayout {
        spacing: Theme.padding

        StatusBaseText {
            Layout.fillWidth: true
            text: qsTr("The swap will revert if the price shifts beyond this percentage.")
            wrapMode: Text.Wrap
            color: Theme.palette.directColor5
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.padding

            Repeater {
                model: d.presets

                delegate: AbstractButton {
                    id: presetButton

                    required property double modelData

                    objectName: "slippagePreset_" + modelData

                    readonly property bool selected: root.slippageValue === modelData

                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 44

                    background: Rectangle {
                        radius: Theme.radius
                        color: presetButton.selected ? Theme.palette.primaryColor3
                             : presetButton.hovered ? Theme.palette.baseColor2
                             : Theme.palette.baseColor4

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    contentItem: StatusBaseText {
                        text: "%L1%".arg(presetButton.modelData)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.weight: Font.Medium
                        color: presetButton.selected ? Theme.palette.primaryColor1
                                                     : Theme.palette.directColor1
                    }

                    onClicked: {
                        root.slippageSelected(modelData)
                        root.close()
                    }
                }
            }
        }

        CurrencyAmountInput {
            id: customInput
            objectName: "slippageCustomInput"

            Layout.fillWidth: true

            placeholderText: qsTr("Custom %")
            currencySymbol: ""
            minValue: 0.01
            maxValue: 100
            maximumLength: 6 // e.g. "100.00"

            onValueChanged: {
                if (valid)
                    root.slippageSelected(value)
            }

            onAccepted: {
                if (valid) {
                    root.slippageSelected(value)
                    root.close()
                }
            }
        }

        StatusBaseText {
            Layout.fillWidth: true
            visible: customInput.length > 0 && !customInput.valid
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.dangerColor1
            text: customInput.value === 0 ? qsTr("Slippage should be more than 0")
                                          : qsTr("Invalid value")
        }

        StatusBaseText {
            Layout.fillWidth: true
            visible: customInput.valid && customInput.length > 0
                     && customInput.value > d.valueTooHighThreshold
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.warningColor1
            text: qsTr("Slippage may be higher than necessary")
        }
    }
}
