import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Qt5Compat.GraphicalEffects

import StatusQ.Controls
import StatusQ.Core
import StatusQ.Core.Backpressure
import StatusQ.Core.Theme

Item {
    id: root

    property rect captureRectangle: Qt.rect(0, 0, 1, 1)

    // Use this property to clip capture rectangle to biggest possible square
    readonly property rect squareCaptureRectangle: {
        const size = Math.min(contentSize.width, contentSize.height)
        const w = size / contentSize.width
        const h = size / contentSize.height
        const x = (1 - w) / 2
        const y = (1 - h) / 2
        return Qt.rect(x, y, w, h)
    }

    property bool highlightContentZone: false
    property bool highlightCaptureZone: false

    readonly property alias cameraAvailable: capture.cameraAvailable
    readonly property size sourceSize: capture.sourceSize
    readonly property size contentSize: capture.contentSize
    readonly property real sourceRatio: capture.sourceRatio

    readonly property int failsCount: capture.failsCount
    readonly property int tagsCount: capture.tagsCount
    readonly property int decodeTime: capture.decodeTime
    readonly property string lastTag: capture.lastTag
    readonly property string currentTag: capture.currentTag

    property int state: StatusQrCodeScanner.State.None

    enum State {
        None,
        Success,
        Error
    }

    signal tagFound(string tag)

    implicitWidth: sourceSize.width
    implicitHeight: sourceSize.height

    QtObject {
        id: d

        readonly property int radius: 16
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.palette.baseColor4
        radius: d.radius
    }

    Item {
        anchors.fill: parent
        visible: capture.cameraAvailable
        clip: true

        StatusQrCodeCapture {
            id: capture

            anchors.fill: parent
            visible: false
            clip: true

            onTagFound: (tag) => root.tagFound(tag)
        }

        Rectangle {
            id: mask
            anchors.fill: parent
            radius: d.radius
            visible: false
            color: "black"
        }

        OpacityMask {
            anchors.fill: parent
            source: capture
            maskSource: mask
        }

        Loader {
            active: root.state === StatusQrCodeScanner.State.Success || root.state === StatusQrCodeScanner.State.Error
            sourceComponent: Rectangle {
                color: {
                    if (root.state === StatusQrCodeScanner.State.Success) {
                        return Theme.palette.successColor2
                    }
                    if (root.state === StatusQrCodeScanner.State.Error) {
                        return Theme.palette.dangerColor3
                    }
                }
                x: capture.contentRect.x
                y: capture.contentRect.y
                width: capture.contentRect.width
                height: capture.contentRect.height
            }
        }
    }

    StatusScanCorners {
        id: scanCorners
        width: root.width / 1.5
        height: width
        anchors.centerIn: parent
        color: {
            if (root.state === StatusQrCodeScanner.State.Success) {
                return Theme.palette.successColor3
            }
            if (root.state === StatusQrCodeScanner.State.Error) {
                return Theme.palette.dangerColor2
            }
            return Theme.palette.baseColor4
        }
    }

    StatusComboBox {
        id: cameraComboBox

        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: 10
        }

        width: Math.min(implicitWidth, parent.width / 2)
        visible: capture.availableCameras.length > 0
        opacity: 0.7
        model: capture.availableCameras
        control.textRole: "displayName"
        control.valueRole: "deviceId"
        control.padding: 8
        control.spacing: 8
        onCurrentValueChanged: {
            // Debounce to close combobox first
            Backpressure.debounce(this, 50, () => { capture.setCameraDevice(currentValue) })()
        }
    }

    ColumnLayout {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 10

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Theme.palette.dangerColor1
            visible: !capture.cameraAvailable
            text: qsTr("Camera is not available")
        }

        StatusBaseText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: Theme.palette.directColor5
            text: capture.cameraError
        }
    }
}

