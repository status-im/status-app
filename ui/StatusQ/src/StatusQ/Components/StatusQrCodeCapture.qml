import QtQuick

import QtMultimedia

import StatusQ.Core.Utils as SQUtils

// Camera preview for QR scanning. Qt only: decoding is done by the host, which
// reads frames from `videoSink` and crops them as the preview shows them.
Item {
    id: root

    readonly property size sourceSize: Qt.size(videoOutput.sourceRect.width,
                                               videoOutput.sourceRect.height)
    readonly property size contentSize: Qt.size(videoOutput.contentRect.width,
                                                videoOutput.contentRect.height)
    readonly property real sourceRatio: videoOutput.sourceRect.width
                                        / videoOutput.sourceRect.height

    readonly property alias contentRect: videoOutput.contentRect

    // Frames of the running camera, for a frame tap / decoder.
    readonly property var videoSink: videoOutput.videoSink

    // How the preview lays out the video (VideoOutput.fillMode / mirrored),
    // for a frame tap that crops each frame as shown.
    readonly property int fillMode: videoOutput.fillMode
    readonly property bool mirrored: videoOutput.mirrored

    // The host gates the camera (visibility, app state).
    property bool active: true

    readonly property var availableCameras: {
        return mediaDevices.videoInputs.map(d => ({
            deviceId: d.id.toString(),
            displayName: d.description
        }))
    }

    readonly property bool cameraAvailable: camera.active
    readonly property string cameraError: camera.error === Camera.CameraError ? camera.errorString : ""

    function setCameraDevice(deviceId: string) {
        camera.cameraDevice = mediaDevices.videoInputs.find(
                    d => d.id.toString() === deviceId)
    }

    MediaDevices {
        id: mediaDevices
    }

    QtObject {
        id: d

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

    CaptureSession {
        camera: Camera {
            id: camera

            active: root.active
            focusMode: Camera.FocusModeAutoNear

            Component.onDestruction: camera.active = false
        }
        videoOutput: videoOutput
    }

    VideoOutput {
        id: videoOutput

        objectName: "qrCaptureVideoOutput"
        anchors.fill: parent
        focus: visible
        mirrored: d.isFrontCamera
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
