import QtQuick
import QtTest
import QtMultimedia

import NimQtCamera 1.0
import NimQrScan 1.0
import Storybook.Testing

// Camera preview → NimQtCamera.FrameTap → host glue (qr_camera_frames.nim) →
// NimQrScan.QrScanner, with synthetic frames instead of a camera.
Item {
    id: root

    width: 320
    height: 240

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
    }

    FrameTap {
        id: tap
        videoSink: videoOutput.videoSink
        maxFps: 0
    }

    QrScanner {
        id: scanner
        frameSource: tap.handle
    }

    FakeVideoSource {
        id: fakeSource
    }

    SignalSpy {
        id: tagSpy
        target: scanner
        signalName: "tagFound"
    }

    TestCase {
        name: "QrScanPipeline"
        when: windowShown

        function test_frameIsDecodedThroughTheGlue() {
            verify(fakeSource.pushQr(videoOutput.videoSink, "pipeline-ok"))
            tryCompare(tagSpy, "count", 1, 5000)
            compare(tagSpy.signalArguments[0][0], "pipeline-ok")
        }
    }
}
