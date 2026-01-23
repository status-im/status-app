import QtQuick

import QtMultimedia
import QZXing
import com.scythestudio.scodes 1.0

Item {
    id: root

    readonly property size sourceSize: Qt.size(videoOutput.sourceRect.width,
                                               videoOutput.sourceRect.height)
    readonly property size contentSize: Qt.size(videoOutput.contentRect.width,
                                                videoOutput.contentRect.height)
    readonly property real sourceRatio: videoOutput.sourceRect.width
                                        / videoOutput.sourceRect.height

    readonly property string lastTag: d.lastTag

    readonly property alias contentRect: videoOutput.contentRect

    required property int captureRectWidth
    required property int captureRectHeight

    readonly property var availableCameras: {
        return mediaDevices.videoInputs.map(d => ({
            deviceId: d.id.toString(),
            displayName: d.description
        }))
    }

    readonly property bool cameraAvailable: barcodeScanner.camera.active
    readonly property string cameraError: barcodeScanner.camera.errorString

    signal tagFound(string tag)

    function setCameraDevice(deviceId: string) {
        barcodeScanner.camera.cameraDevice = mediaDevices.videoInputs.find(
                    d => d.id.toString() === deviceId)
    }

    MediaDevices {
        id: mediaDevices
    }

    QtObject {
        id: d

        property string lastTag
    }


    SBarcodeScanner {
        id: barcodeScanner

        forwardVideoSink: videoOutput.videoSink
        scanning: true

        captureRect: contentZoneHighlight

        onCapturedChanged: (tag) => {
            d.lastTag = tag
            root.tagFound(tag)
        }
    }

    VideoOutput {
        id: videoOutput

        anchors.fill: parent

        width: root.width

        focus: visible
        fillMode: VideoOutput.PreserveAspectCrop
    }
    Rectangle {
        id: captureRect
        width: root.captureRectWidth
        height: root.captureRectHeight
        anchors.centerIn: parent
        visible: false
    }
}
