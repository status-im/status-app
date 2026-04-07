pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Controls

StatusSlider {
    id: root

    property var model: []
    property string textRole: ""
    property string valueRole: ""

    property int fontSize: Theme.tertiaryTextFontSize
    property int labelMargin: 2

    readonly property string currentText: Array.isArray(root.model)
                                          ? root.model[value]
                                          : root.model.get(value)[root.textRole]

    readonly property var currentValue: Array.isArray(root.model)
                                        ? root.model[value]
                                        : root.model.get(value)[root.valueRole]

    fillColor: bgColor
    handleColor: Theme.palette.primaryColor1
    handleSize: 14
    from: 0
    to: (Array.isArray(model) ? model.length : model.count) - 1
    stepSize: 1
    snapMode: Slider.SnapAlways

    decoration: Item {
        implicitHeight: handleSize + fontSize + labelMargin

        Repeater {
            id: repeater
            model: root.model

            Rectangle {
                x: (parent.width) / (repeater.count - 1) * index - width * 0.5
                y: (root.bgHeight -height) / 2
                implicitWidth: root.handleSize
                implicitHeight: root.handleSize
                radius: root.handleSize / 2
                color: root.bgColor
                border.color: Theme.palette.statusAppLayout.backgroundColor
                border.width: 2

                StatusBaseText {
                    anchors.top: parent.bottom
                    anchors.topMargin: root.labelMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Qt.AlignHCenter
                    color: Theme.palette.baseColor1
                    font.pixelSize: root.fontSize

                    text: root.textRole ? (Array.isArray(root.model)
                                              ? modelData[root.textRole]
                                              : model[root.textRole])
                                           : modelData
                }
            }
        }
    }
}
