import QtQuick
import QtQuick.Shapes

import StatusQ.Core
import StatusQ.Core.Theme

Item {
    id: root

    property int timeoutSeconds: 60
    property int secondsLeft: timeoutSeconds
    property bool running: true
    property int indicatorSize: 72
    property int strokeWidth: 4
    property color backgroundColor: Theme.palette.baseColor2
    property color progressColor: Theme.palette.primaryColor1
    property color textColor: Theme.palette.primaryColor1
    property int textPixelSize: Theme.additionalTextSize
    property int textWeight: Font.Medium
    property string countdownText: qsTr("%1s").arg(secondsLeft)

    QtObject {
        id: d

        readonly property int progressIndicatorCenter: root.indicatorSize / 2
        readonly property real progressIndicatorRadius: root.indicatorSize / 2 - root.strokeWidth / 2
        readonly property int progressStartAngle: -90
        readonly property int fullCircleAngle: 360
        readonly property real minimumProgressSweepAngle: 0.01
        readonly property int safeTimeout: Math.max(1, root.timeoutSeconds)
        readonly property real progress: Math.max(0, Math.min(1, 1 - root.secondsLeft / safeTimeout))
    }

    implicitWidth: indicatorSize
    implicitHeight: indicatorSize

    Shape {
        anchors.fill: parent
        visible: root.running
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.backgroundColor
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: d.progressIndicatorCenter
                centerY: d.progressIndicatorCenter
                radiusX: d.progressIndicatorRadius
                radiusY: d.progressIndicatorRadius
                startAngle: d.progressStartAngle
                sweepAngle: d.fullCircleAngle
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.progressColor
            strokeWidth: root.strokeWidth
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: d.progressIndicatorCenter
                centerY: d.progressIndicatorCenter
                radiusX: d.progressIndicatorRadius
                radiusY: d.progressIndicatorRadius
                startAngle: d.progressStartAngle
                sweepAngle: Math.max(d.minimumProgressSweepAngle, d.fullCircleAngle * d.progress)
            }
        }
    }

    StatusBaseText {
        anchors.centerIn: parent
        visible: root.running
        text: root.countdownText
        color: root.textColor
        font.pixelSize: root.textPixelSize
        font.weight: root.textWeight
    }
}
