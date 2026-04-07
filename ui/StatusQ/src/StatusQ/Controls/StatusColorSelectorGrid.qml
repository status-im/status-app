pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme

Control {
    id: root

    property alias titleText: title.text
    property alias title: title
    property alias columns: grid.columns

    property int diameter: 48
    property int selectorDiameter: 20

    property int selectedColorIndex: 0
    property string selectedColor: ""
    property var model: Theme.palette.customisationColorsArray

    signal colorSelected(color color)

    contentItem: ColumnLayout {
        implicitWidth: d.contentImplicitWidth
        spacing: 0

        StatusBaseText {
            id: title

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Layout.bottomMargin: 16

            elide: Text.ElideRight
            color: Theme.palette.baseColor1
        }

        QtObject {
            id: d

            readonly property int defaultColumns: 6
            readonly property int contentImplicitWidth:
                defaultColumns * root.diameter +
                (defaultColumns - 1) * baseColumnSpacing

            readonly property int baseRowSpacing: 16
            readonly property int baseColumnSpacing: 32
            readonly property real stretchFactor:
                root.availableWidth / (columns * root.diameter + (columns - 1) * baseColumnSpacing)

        }

        Grid {
            id: grid

            columns: {
                if (root.availableWidth < d.contentImplicitWidth / 2)
                    return 3

                return root.availableWidth < d.contentImplicitWidth ? 4 : 6
            }

            rowSpacing: d.baseRowSpacing * d.stretchFactor
            columnSpacing: d.baseColumnSpacing * d.stretchFactor

            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop

            Repeater {
                objectName: "statusColorRepeater"
                model: root.model
                delegate: StatusColorRadioButton {
                    implicitWidth: root.diameter * d.stretchFactor
                    implicitHeight: root.diameter * d.stretchFactor
                    diameter: root.diameter * d.stretchFactor
                    selectorDiameter: root.selectorDiameter * d.stretchFactor
                    checked: index === selectedColorIndex
                    radioButtonColor: root.model[index] || "transparent"
                    onCheckedChanged: {
                        if (checked) {
                            selectedColorIndex = index;
                            selectedColor = root.model[index];
                            root.colorSelected(selectedColor);
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
