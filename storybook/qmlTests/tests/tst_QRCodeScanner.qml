import QtQuick
import QtTest

import StatusQ.Components
import StatusQ.Controls.Validators

import Storybook.Testing

import shared.controls

// QRCodeScanner decoding, with synthetic frames pushed straight into the
// preview's video sink: no camera is needed.
Item {
    id: root

    width: 400
    height: 500

    readonly property string address: "0x1234567890abcdef1234567890abcdef12345678"

    // Granted regardless of the host: QmlTests has no Info.plist, so on macOS
    // the real CameraAccess reports "denied".
    QtObject {
        id: grantedAccess

        readonly property string status: "granted"
        readonly property bool granted: true
        readonly property bool canOpenSettings: false
        function request() {}
        function openSettings() { return false }
    }

    Component {
        id: componentUnderTest

        QRCodeScanner {
            anchors.fill: parent
            cameraAccess: grantedAccess
            validators: [
                StatusValidator {
                    errorMessage: "not an address"
                    validate: value => value.startsWith("0x")
                }
            ]
        }
    }

    FakeVideoSource {
        id: fakeSource
    }

    SignalSpy {
        id: tagSpy
        signalName: "validTagFound"
    }

    property QRCodeScanner controlUnderTest: null

    TestCase {
        name: "QRCodeScanner"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            tagSpy.target = controlUnderTest
            tagSpy.clear()
        }

        function videoOutput() {
            let output = null
            tryVerify(() => {
                output = findChild(controlUnderTest, "qrCaptureVideoOutput")
                return !!output
            })
            return output
        }

        function test_validTagFound() {
            verify(fakeSource.pushQr(videoOutput().videoSink, root.address, 640, 640))
            tryCompare(tagSpy, "count", 1, 5000)
            compare(tagSpy.signalArguments[0][0], root.address)
            compare(controlUnderTest.state, StatusQrCodeScanner.State.Success)
        }

        function test_invalidTagSetsError() {
            verify(fakeSource.pushQr(videoOutput().videoSink, "not-an-address", 640, 640))
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.Error, 5000)
            compare(tagSpy.count, 0)
        }

        // One accepted code per scan, even when the frame holds two.
        function test_oneTagPerFrameWithTwoCodes() {
            const other = "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"
            verify(fakeSource.pushTwoQrs(videoOutput().videoSink, root.address, other, 1200, 1200))
            tryCompare(tagSpy, "count", 1, 5000)
            wait(300)
            compare(tagSpy.count, 1)
            compare(controlUnderTest.state, StatusQrCodeScanner.State.Success)
        }

        // Only the area inside the scan corners is decoded.
        function test_roiFollowsScanCorners() {
            const output = videoOutput()
            // A blank frame first: it sets the preview geometry, so the scan
            // area (ROI) is known before any code is shown.
            verify(fakeSource.pushBlank(output.videoSink, 1200, 1200))
            tryCompare(output.sourceRect, "width", 1200)

            // Streamed like a camera: the tap is rate-limited (maxFps) and
            // drops frames that arrive too soon after the previous pull.
            for (let i = 0; i < 10; ++i) {
                verify(fakeSource.pushQrAt(output.videoSink, root.address, 0, 0, 1200, 1200))
                wait(150)
            }
            compare(tagSpy.count, 0)

            verify(fakeSource.pushQr(output.videoSink, root.address, 1200, 1200))
            tryCompare(tagSpy, "count", 1, 5000)
        }

        // A decode still running when the scanner is hidden must not report.
        function test_noTagAfterHide() {
            const sink = videoOutput().videoSink
            verify(fakeSource.pushSlowQr(sink, root.address))
            controlUnderTest.visible = false
            wait(3000)
            compare(tagSpy.count, 0)

            // Still scanning once shown again.
            controlUnderTest.visible = true
            verify(fakeSource.pushQr(sink, root.address, 640, 640))
            tryCompare(tagSpy, "count", 1, 5000)
        }
    }
}
