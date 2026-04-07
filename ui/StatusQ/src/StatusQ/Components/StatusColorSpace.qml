pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects

import StatusQ.Core
import StatusQ.Core.Theme

Item {
    id: root

    property int thickness: width * 0.1
    property real minSaturate: 0.0
    property real minValue: 0.0
    property real maxSaturate: 1.0
    property real maxValue: 1.0
    property color color: "red"
    property color rootColor: Qt.hsva(color.hsvHue, 1, 1, 1)

    function pickColorFromHueGauge(x: real, y: real): color {
        // Get angle of picked color
        let theta = Math.atan2(y - hueGauge.height / 2, x - hueGauge.width / 2) * 0.5 / Math.PI;
        if (theta < 0.0)
            theta += 1.0;

        // Convert angle value to color
        return Qt.hsva(1 - theta, 1, 1, 1)
    }

    function pickColorFromSatValRect(x: real, y: real): color {
        // x for saturation, reversed y for value
        let sat = mapFromRange(Math.min(Math.max(x, 0), satValRect.width),
                               minSaturate, maxSaturate, satValRect.width);
        let val = 1 - mapFromRange(Math.min(Math.max(y, 0), satValRect.height),
                                   1 - maxValue, 1 - minValue, satValRect.height);
        return Qt.hsva(rootColor.hsvHue, sat, val, 1);
    }

    function angleOnHueGauge(pickingColor: color): real {
        // color hue to angle
        return (1 - pickingColor.hsvHue) * 2 * Math.PI;
    }

    // TODO: mapToRange & mapFromRange to helper js
    function mapToRange(value: real, minValue: real, maxValue: real, range: real): real {
        return (value - minValue) / (maxValue - minValue) * range;
    }

    function mapFromRange(pos: real, minValue: real, maxValue: real, range: real): real {
        return pos / range * (maxValue - minValue) + minValue;
    }

    onColorChanged: {
        // update root color if only we are not picking on satValRect
        if (!d.pickingSatVal)
            rootColor = Qt.hsva(color.hsvHue, 1, 1, 1)
    }

    implicitWidth: 340
    implicitHeight: 340

    QtObject {
        id: d

        property bool pickingSatVal: false
    }

    ConicalGradient {
        id: hueGauge
        anchors.fill: parent
        angle: 90.0
        gradient: Gradient {
            GradientStop { position: 0.000; color: Qt.hsva(1.000, 1, 1, 1) }
            GradientStop { position: 0.167; color: Qt.hsva(0.833, 1, 1, 1) }
            GradientStop { position: 0.333; color: Qt.hsva(0.666, 1, 1, 1) }
            GradientStop { position: 0.500; color: Qt.hsva(0.500, 1, 1, 1) }
            GradientStop { position: 0.667; color: Qt.hsva(0.333, 1, 1, 1) }
            GradientStop { position: 0.833; color: Qt.hsva(0.166, 1, 1, 1) }
            GradientStop { position: 1.000; color: Qt.hsva(0.000, 1, 1, 1) }
        }
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Item {
                width: root.width
                height: root.height

                Rectangle {
                    anchors.fill: parent
                    radius: Math.min(width, height) / 2
                }
            }
        }

        StatusMouseArea {
            id: hueArea

            property bool hoverOnGauge: false

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: hoverOnGauge ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPositionChanged: {
                // Check we hovering gauge
                let dist = Math.sqrt(Math.pow(width / 2 - mouseX, 2) +
                                     Math.pow(height / 2 - mouseY, 2));
                let radius = Math.min(width, height) / 2;
                hoverOnGauge = !(dist < radius - thickness || dist > radius);

                if (hoverOnGauge && pressed)
                    pickRootColor();
            }
            onPressed: {
                if (hoverOnGauge)
                    pickRootColor();
            }

            function pickRootColor() {
                // Update both colors
                rootColor = pickColorFromHueGauge(mouseX, mouseY);
                color.hsvHue = rootColor.hsvHue;
                color.hsvSaturation = Math.min(maxSaturate, Math.max(minSaturate, color.hsvSaturation));
                color.hsvValue = Math.min(maxValue, Math.max(minValue, color.hsvValue));
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.thickness
        radius: Math.min(width, height) / 2

        color: Theme.palette.baseColor5

        Rectangle {
            id: satValRect
            anchors.centerIn: parent
            width: parent.width * 0.55
            height: width
            border.color: Theme.palette.baseColor3
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: -minSaturate; color: "white" }
                GradientStop { position: 2.0 - maxSaturate; color: rootColor }
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: maxValue - 1; color: "transparent" }
                    GradientStop { position: 1.0 + minValue; color: "black" }
                }
            }

            StatusMouseArea {
                id: satValArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: containsMouse ? Qt.PointingHandCursor : Qt.ArrowCursor
                onPressed: {
                    d.pickingSatVal = true;
                    pickColor();
                }
                onReleased: d.pickingSatVal = false
                onPositionChanged: if (pressed) pickColor()

                function pickColor() {
                    root.color = pickColorFromSatValRect(mouseX, mouseY);
                }
            }

            Rectangle {
                id: satValLens
                x: mapToRange(root.color.hsvSaturation, minSaturate, maxSaturate,
                              satValRect.width) - radius
                y: mapToRange(1 - root.color.hsvValue, 1 - maxValue, 1 - minValue,
                              satValRect.height) - radius
                width: thickness * 1.3
                height: width
                radius: height / 2
                border.width: 2
                border.color: Theme.palette.baseColor3
                color: root.color
                visible: x + 1 >= -radius && x - 1 <= satValRect.width - radius &&
                         y + 1 >= -radius && y - 1 <= satValRect.height - radius
            }
        }
    }

    Rectangle {
        id: hueLens

        property real theta: angleOnHueGauge(rootColor);
        property real dist: (hueGauge.width - width) / 2 + thickness / 6;

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: dist * Math.cos(theta);
        anchors.verticalCenterOffset: dist * Math.sin(theta);
        width: thickness * 1.3
        height: width
        radius: height / 2
        border.width: 2
        border.color: Theme.palette.baseColor3
        color: rootColor
    }
}
