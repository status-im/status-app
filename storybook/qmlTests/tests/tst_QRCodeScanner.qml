import QtQuick
import QtTest

import StatusQ.Components
import StatusQ.Core.Theme
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

        // No warm-up frame: the very first frames, before the preview has laid
        // out the video, must already be cropped to the scan corners.
        // 1600x900 into the ~400x430 scanner (cropped left/right): the scan
        // corners cover raw x ≈ 0.31..0.69. A code at raw x 260..408 px
        // (0.16..0.26) is outside them, but inside if the item rect were
        // taken for the video (x 0.14..0.86) or the whole frame were used.
        function test_roiAppliesFromTheFirstFrame() {
            const sink = videoOutput().videoSink
            for (let i = 0; i < 10; ++i) {
                verify(fakeSource.pushQrAt(sink, root.address, 260, 376, 1600, 900))
                wait(150)
            }
            compare(tagSpy.count, 0)
            verify(fakeSource.pushQrAt(sink, root.address, 726, 376, 1600, 900))
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

        function statusScanner() {
            const scanner = findChild(controlUnderTest, "statusQrCodeScanner")
            verify(!!scanner)
            return scanner
        }

        function flashlightButton() {
            const button = findChild(controlUnderTest, "qrFlashlightButton")
            verify(!!button)
            return button
        }

        // No camera here, so no torch: no flashlight button.
        function test_noFlashlightWithoutTorch() {
            compare(statusScanner().flashlightAvailable, false)
            compare(flashlightButton().visible, false)
        }

        // Left of the upload button, the same size, on the same line.
        function test_flashlightLeftOfUploadButton() {
            const scanner = statusScanner()
            scanner.flashlightAvailable = true // a device with a torch
            const flash = flashlightButton()
            const upload = findChild(scanner, "qrUploadImageButton")
            verify(flash.visible && !!upload)
            compare(flash.width, upload.width)
            compare(flash.height, upload.height)
            compare(flash.icon.name, "flashlight-off")
            const f = flash.mapToItem(scanner, 0, 0)
            const u = upload.mapToItem(scanner, 0, 0)
            compare(f.x, 12)
            verify(u.x > f.x + flash.width, "upload button right of the flashlight")
            compare(f.y, u.y)
            // styled like the camera picker
            const picker = findChild(scanner, "qrCameraComboBox")
            compare(String(flash.normalColor), String(flash.Theme.palette.baseColor2))
            compare(flash.opacity, picker.opacity)
            compare(upload.opacity, picker.opacity)
        }

        function test_flashlightToggles() {
            const scanner = statusScanner()
            scanner.flashlightAvailable = true
            const flash = flashlightButton()
            mouseClick(flash)
            compare(scanner.flashlightOn, true)
            compare(flash.icon.name, "flashlight-on")
            compare(String(flash.normalColor), String(flash.StatusColors.white))
            compare(findChild(scanner, "qrCodeCapture").torchOn, true)
            mouseClick(flash)
            compare(scanner.flashlightOn, false)
            compare(flash.icon.name, "flashlight-off")
            compare(findChild(scanner, "qrCodeCapture").torchOn, false)
        }

        // The camera stops (background, dialog closed): the light goes off.
        function test_flashlightOffWhenCameraStops() {
            const scanner = statusScanner()
            scanner.flashlightAvailable = true
            mouseClick(flashlightButton())
            compare(scanner.flashlightOn, true)
            appState.setActive(false)
            compare(scanner.flashlightOn, false)
            appState.setActive(true)
            compare(scanner.flashlightOn, false)
        }

        // Background (mobile) / lost focus (desktop): no camera, no scanning.
        // Counts the scanner's entries into the Error state.
        function errorEntries() {
            const counter = { count: 0 }
            controlUnderTest.stateChanged.connect(() => {
                if (controlUnderTest.state === StatusQrCodeScanner.State.Error)
                    counter.count++
            })
            return counter
        }

        // Keeps the codes in view (in turn, one per frame) for `ms`.
        function hold(sink, codes, ms) {
            const t0 = Date.now()
            for (let i = 0; Date.now() - t0 < ms; ++i) {
                verify(fakeSource.pushQr(sink, codes[i % codes.length], 640, 640))
                wait(150)
            }
        }

        // A rejected code held in view errors (and vibrates) once, not once
        // per 2-second error cycle (issue 22943).
        function test_heldInvalidCodeErrorsOnce() {
            const sink = videoOutput().videoSink
            const errors = errorEntries()
            hold(sink, ["not-an-address"], 3000)
            compare(errors.count, 1)
            compare(tagSpy.count, 0)
        }

        // Taken out of view and shown again: it errors (and vibrates) again.
        function test_rejectedCodeShownAgainErrorsAgain() {
            const sink = videoOutput().videoSink
            const errors = errorEntries()
            hold(sink, ["not-an-address"], 3000)
            compare(errors.count, 1)
            wait(1500) // out of view: no frame shows it
            hold(sink, ["not-an-address"], 500)
            compare(errors.count, 2)
        }

        function errorText() {
            const text = findChild(controlUnderTest, "qrScannerErrorText")
            verify(!!text)
            return text
        }

        // The error stays while the rejected code is in view, past the
        // 2-second Error state: the scanner is ignoring it, not scanning.
        function test_errorStaysWhileRejectedCodeInView() {
            const sink = videoOutput().videoSink
            hold(sink, ["not-an-address"], 4000)
            compare(controlUnderTest.state, StatusQrCodeScanner.State.None)
            compare(errorText().text, "not an address")
        }

        // Taken out of view: the error clears (the hint comes back).
        function test_errorClearsWhenRejectedCodeGone() {
            const sink = videoOutput().videoSink
            verify(fakeSource.pushQr(sink, "not-an-address", 640, 640))
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.Error, 5000)
            compare(errorText().text, "not an address")
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.None, 3000)
            tryCompare(errorText(), "text", "", 2000)
        }

        // Two rejected codes in view: one error each, not alternating forever.
        function test_twoInvalidCodesErrorOnceEach() {
            const sink = videoOutput().videoSink
            const errors = errorEntries()
            hold(sink, ["not-an-address", "not-an-address-either"], 5500)
            compare(errors.count, 2)
        }

        // A new session (reset, e.g. the dialog reopened) checks it again.
        function test_resetRevalidatesRejectedCode() {
            const sink = videoOutput().videoSink
            const errors = errorEntries()
            verify(fakeSource.pushQr(sink, "not-an-address", 640, 640))
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.Error, 5000)
            controlUnderTest.reset()
            hold(sink, ["not-an-address"], 1000)
            compare(errors.count, 2)
        }

        // A valid code after a rejected one is still accepted.
        function test_validCodeAfterRejectedCode() {
            const sink = videoOutput().videoSink
            verify(fakeSource.pushQr(sink, "not-an-address", 640, 640))
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.Error, 5000)
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.None, 3000)
            verify(fakeSource.pushQr(sink, root.address, 640, 640))
            tryCompare(tagSpy, "count", 1, 5000)
            compare(tagSpy.signalArguments[0][0], root.address)
        }

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
