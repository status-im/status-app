import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

Control {
    id: root

    property double value: defaultValue

    readonly property double defaultValue: 0.5

    readonly property bool valid: customInput.length === 0 || customInput.valid

    property double valueTooHighThreshold: 5

    signal edited(double newValue)

    signal committed()

    QtObject {
        id: d

        readonly property var presets: [0.1, 0.5, 1]
    }

    Component.onCompleted: Qt.callLater(() => {
        if (d.presets.includes(root.value))
            customInput.clear()
        else
            customInput.value = root.value
    })

    background: null

    contentItem: ColumnLayout {
        spacing: Theme.padding

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.padding

            Repeater {
                objectName: "presetsRepeater"
                model: d.presets

                delegate: AbstractButton {
                    id: presetButton

                    required property double modelData

                    objectName: "slippagePreset_" + modelData

                    readonly property bool selected: root.value === modelData

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
                        customInput.clear()
                        root.edited(modelData)
                        root.committed()
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

            function applyIfValid() {
                if (valid && length > 0)
                    root.edited(value)
            }
            onValueChanged: Qt.callLater(applyIfValid)
            onAcceptableInputChanged: Qt.callLater(applyIfValid)

            onAccepted: {
                if (valid) {
                    root.edited(value)
                    root.committed()
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
                     && customInput.value > root.valueTooHighThreshold
            font.pixelSize: Theme.tertiaryTextFontSize
            color: Theme.palette.warningColor1
            text: qsTr("Slippage may be higher than necessary")
        }
    }
}
