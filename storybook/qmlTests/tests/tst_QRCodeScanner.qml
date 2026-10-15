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

    AppStateDriver {
        id: appState
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

        function cleanup() {
            appState.setActive(true)
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
            // contentRect (and so the ROI) follows on a queued update: wait for
            // the square video laid out, cropped left and right
            tryVerify(() => output.contentRect.width > output.width + 1)

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

        // Phone cameras deliver rotated frames that the preview rotates for
        // display; the scan corners are measured on the display, so only what
        // is inside them on screen may be decoded.
        function test_roiFollowsScanCornersOnRotatedFrames() {
            const output = videoOutput()
            // raw 1600x900, shown rotated 90° clockwise: a 900x1600 portrait preview
            verify(fakeSource.pushBlank(output.videoSink, 1600, 900, 90)) // geometry first
            // contentRect follows a frame on a queued update (sourceRect at once):
            // wait until the portrait video is laid out, cropped top and bottom
            tryVerify(() => output.contentRect.height > output.height + 1)
            const r = findChild(controlUnderTest, "statusQrCodeScanner").normalizedCaptureRect
            // displayed scan area ≈ x 0.14..0.86, y 0.30..0.70, i.e. raw
            // x 0.30..0.70 (480..1120 px), y 0.14..0.86 (126..774 px)
            verify(Math.abs(r.x - 0.14) < 0.03 && Math.abs(r.y - 0.30) < 0.03,
                   JSON.stringify(r))

            // raw (280, 376), 148 px: inside the scan area if the rect were
            // applied to the raw frame unrotated, outside it on screen
            for (let i = 0; i < 10; ++i) {
                verify(fakeSource.pushQrAtRotated(output.videoSink, root.address,
                                                  280, 376, 1600, 900, 90))
                wait(150)
            }
            compare(tagSpy.count, 0)

            // the raw centre is the displayed centre: decodes
            verify(fakeSource.pushQrAtRotated(output.videoSink, root.address,
                                              726, 376, 1600, 900, 90))
            tryCompare(tagSpy, "count", 1, 5000)
        }

        // Background (mobile) / lost focus (desktop): no camera, no scanning.
        function test_noScanWhileAppInactive() {
            const sink = videoOutput().videoSink
            const scanner = findChild(controlUnderTest, "statusQrCodeScanner")
            verify(!!scanner)
            compare(scanner.capturing, true)

            appState.setActive(false)
            compare(Qt.application.state, Qt.ApplicationInactive)
            compare(scanner.capturing, false) // camera stopped
            for (let i = 0; i < 5; ++i) {
                verify(fakeSource.pushQr(sink, root.address, 640, 640))
                wait(150)
            }
            compare(tagSpy.count, 0)

            appState.setActive(true)
            compare(scanner.capturing, true)
            verify(fakeSource.pushQr(sink, root.address, 640, 640))
            tryCompare(tagSpy, "count", 1, 5000)
        }

        // A decode still running when the app goes inactive must not report.
        function test_noTagWhenDeactivatedMidDecode() {
            const sink = videoOutput().videoSink
            verify(fakeSource.pushSlowQr(sink, root.address))
            appState.setActive(false)
            wait(3000)
            compare(tagSpy.count, 0)

            appState.setActive(true)
            verify(fakeSource.pushQr(sink, root.address, 640, 640))
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
