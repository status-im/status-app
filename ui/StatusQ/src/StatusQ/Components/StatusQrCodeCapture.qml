import QtQuick

import QtMultimedia
import com.scythestudio.scodes 1.0

import StatusQ.Core.Utils as SQUtils

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

    readonly property bool cameraAvailable: camera.active
    readonly property string cameraError: camera.error === Camera.CameraError ? camera.errorString : ""

    signal tagFound(string tag)

    function setCameraDevice(deviceId: string) {
        camera.cameraDevice = mediaDevices.videoInputs.find(
                    d => d.id.toString() === deviceId)
    }

    MediaDevices {
        id: mediaDevices
    }

    QtObject {
        id: d

        property string lastTag
        readonly property bool isFrontCamera: {
            // On desktop, cameras often report position as 0 (BackFace) or -1 (UnspecifiedPosition)
            // Default to mirroring (front camera behavior) on desktop
            if (!SQUtils.Utils.isMobile) {
                return true
            }
            // On mobile, check actual position
            return camera.cameraDevice.position === Camera.FrontFace
        }
    }


    SBarcodeScanner {
        id: barcodeScanner

        forwardVideoSink: videoOutput.videoSink
        camera: camera
        scanning: true

        captureRect: captureRectangle

        onCapturedChanged: (tag) => {
            d.lastTag = tag
            root.tagFound(tag)
        }
    }

    Camera {
        id: camera

        active: true
        focusMode: Camera.FocusModeAutoNear

        Component.onDestruction: camera.active = false
    }

    VideoOutput {
        id: videoOutput

        anchors.fill: parent
        focus: visible
        mirrored: d.isFrontCamera
        fillMode: VideoOutput.PreserveAspectCrop
    }

    Rectangle {
        id: captureRectangle
        width: root.captureRectWidth
        height: root.captureRectHeight
        anchors.centerIn: parent
        visible: false
    }
}
