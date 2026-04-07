pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls
import StatusQ.Controls.Validators
import StatusQ.Components
import StatusQ.Popups

StatusModal {
    id: root

    property alias color: colorSpace.color
    property alias standardColors: colorSelectionGrid.model
    property alias acceptText: acceptButton.text
    property alias previewText: preview.text

    signal accepted()

    onColorChanged: {
        if (!hexInput.locked)
            hexInput.text = color.toString();

        if (colorSelectionGrid.selectedColor != color)
            colorSelectionGrid.selectedColorIndex = -1;
    }
    Component.onCompleted: {
        hexInput.text = color.toString();
    }

    width: 680

    StatusScrollView {
        id: scroll
        anchors.fill: parent
        padding: 20

        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: column
            width: scroll.availableWidth
            spacing: 16

            StatusColorSpace {
                id: colorSpace

                property real hueFactor: Math.max(rootColor.g + rootColor.b * 0.4,
                                                  rootColor.g + rootColor.r * 0.6)

                minSaturate: Math.max(0.4, hueFactor * 0.55)
                maxSaturate: 1.0
                minValue: 0.4
                // Curve to pick colors readable with white text
                maxValue: Math.min(1.0, 1.65 - hueFactor * 0.5)
                Layout.alignment: Qt.AlignHCenter
            }

            StatusInput {
                id: hexInput

                property color newColor: text
                // TODO: editingFinished() signal instead of this crutch
                property bool locked: false

                implicitWidth: 256
                validators: [
                    StatusRegularExpressionValidator {
                        regularExpression: /^#(?:[0-9a-fA-F]{3}){1,2}$/
                        errorMessage: qsTr("This is not a valid colour")
                    }
                ]
                validationMode: StatusInput.ValidationMode.Always

                onNewColorChanged: {
                    if (!valid)
                        return;

                    locked = true;
                    root.color = newColor;
                    locked = false;
                }
                Layout.alignment: Qt.AlignHCenter
            }

            StatusBaseText {
                text: qsTr("Preview")
            }

            Rectangle {
                implicitHeight: 48
                radius: 10
                color: root.color
                Layout.fillWidth: true

                StatusBaseText {
                    id: preview
                    x: 16
                    y: 16
                    text: root.color.toString()
                    color: StatusColors.white
                }
            }

            StatusColorSelectorGrid {
                id: colorSelectionGrid
                titleText: qsTr("Standard colours")
                title.color: Theme.palette.directColor1
                title.font.pixelSize: Theme.primaryTextFontSize
                columns: 8
                model: ["#4360df", "#887af9", "#d37ef4", "#51d0f0", "#26a69a", "#7cda00", "#eab700", "#fa6565"]
                selectedColorIndex: -1
                onColorSelected: {
                    root.color = selectedColor;
                }
                Layout.fillWidth: true
            }
        }
    }

    rightButtons: [
        StatusButton {
            id: acceptButton
            text: qsTr("Select Colour")
            onClicked: {
                root.accepted();
                root.close();
            }
        }
    ]
}
