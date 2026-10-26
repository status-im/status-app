import QtQuick
import QtTest

import StatusQ.Components
import StatusQ.Core.Theme
import StatusQ.Controls.Validators

import Storybook.Testing

import shared.controls

// QRCodeScanner's "Upload image": codes from a picked image file go through
// the scanner's validators like camera codes; image problems show a
// non-blocking 4-second message.
Item {
    id: root

    width: 400
    height: 500

    readonly property string address: "0x1234567890abcdef1234567890abcdef12345678"

    QtObject {
        id: grantedAccess

        readonly property string status: "granted"
        readonly property bool granted: true
        readonly property bool canRequest: false
        readonly property bool canOpenSettings: false
        function request() {}
        function openSettings() { return false }
    }

    QtObject {
        id: deniedAccess

        readonly property string status: "denied"
        readonly property bool granted: false
        readonly property bool canRequest: false
        readonly property bool canOpenSettings: true
        function request() {}
        function openSettings() { return true }
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
        id: fake
    }

    SignalSpy {
        id: tagSpy
        signalName: "validTagFound"
    }

    property QRCodeScanner controlUnderTest: null

    TestCase {
        name: "QRCodeScannerImage"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            tagSpy.target = controlUnderTest
            tagSpy.clear()
        }

        function file(name) {
            return fake.tempPath("qrscanner-image-" + name)
        }

        function scan(path) {
            controlUnderTest.scanImageFile(fake.fileUrl(path))
        }

        function expectImageError(text) {
            tryCompare(controlUnderTest, "imageErrorMessage", text, 5000)
            compare(controlUnderTest.state, StatusQrCodeScanner.State.None)
            compare(tagSpy.count, 0)
        }

        function unsupportedText() {
            const decoder = findChild(controlUnderTest, "qrImageDecoder")
            verify(!!decoder)
            return decoder.heicSupported
                    ? "Unsupported format. Select a JPG, PNG, or HEIC image"
                    : "Unsupported format. Select a JPG or PNG image"
        }

        function test_validCodeImageFound() {
            verify(fake.writeQrImage(file("valid.png"), root.address))
            scan(file("valid.png"))
            tryCompare(tagSpy, "count", 1, 5000)
            compare(tagSpy.signalArguments[0][0], root.address)
            compare(controlUnderTest.state, StatusQrCodeScanner.State.Success)
        }

        function test_jpegImageFound() {
            verify(fake.writeQrImage(file("valid.jpg"), root.address, "JPG"))
            scan(file("valid.jpg"))
            tryCompare(tagSpy, "count", 1, 5000)
        }

        // Req. 4: a decoded code goes through the existing validators.
        function test_invalidCodeImageUsesValidator() {
            verify(fake.writeQrImage(file("invalid.png"), "not-an-address"))
            scan(file("invalid.png"))
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.Error, 5000)
            compare(tagSpy.count, 0)
            verify(!!findChild(controlUnderTest, "qrScannerErrorText"))
            compare(findChild(controlUnderTest, "qrScannerErrorText").text, "not an address")
        }

        // Picking an image is an explicit action: a rejected code errors again
        // each time (only the camera ignores a code it already rejected).
        function test_rejectedImageCodeErrorsEachTime() {
            verify(fake.writeQrImage(file("invalid-again.png"), "not-an-address"))
            scan(file("invalid-again.png"))
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.Error, 5000)
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.None, 3000)
            scan(file("invalid-again.png"))
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.Error, 5000)
            compare(tagSpy.count, 0)
        }

        // As for a camera code: the validator's message stays after the
        // 2-second Error state ends, until something replaces it.
        function test_validatorErrorStaysAfterErrorState() {
            verify(fake.writeQrImage(file("invalid-stays.png"), "not-an-address"))
            scan(file("invalid-stays.png"))
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.Error, 5000)
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.None, 3000)
            const text = findChild(controlUnderTest, "qrScannerErrorText")
            compare(text.text, "not an address")
            // then gone after 4 seconds in all, like the other image errors
            wait(1000)
            compare(text.text, "not an address")
            tryCompare(text, "text", "", 2000)
        }

        // An image error replaces a lingering validator message, and leaves
        // nothing behind when its 4 seconds are up.
        function test_imageErrorReplacesValidatorError() {
            verify(fake.writeQrImage(file("invalid-repl.png"), "not-an-address"))
            verify(fake.writeBlankImage(file("blank-repl.png")))
            scan(file("invalid-repl.png"))
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.Error, 5000)
            tryCompare(controlUnderTest, "state", StatusQrCodeScanner.State.None, 3000)
            scan(file("blank-repl.png"))
            const text = findChild(controlUnderTest, "qrScannerErrorText")
            tryCompare(text, "text", "No QR code found in the image", 5000)
            tryCompare(text, "text", "", 5000)
        }

        function test_validCodeChosenAmongTwo() {
            verify(fake.writeTwoQrsImage(file("two.png"), "not-an-address", root.address))
            scan(file("two.png"))
            tryCompare(tagSpy, "count", 1, 5000)
            compare(tagSpy.signalArguments[0][0], root.address)
        }

        function test_noCodeShowsError() {
            verify(fake.writeBlankImage(file("blank.png")))
            scan(file("blank.png"))
            expectImageError("No QR code found in the image")
        }

        function test_undecodableCodeShowsError() {
            verify(fake.writeDamagedQrImage(file("damaged.png"),
                                            "an image whose code is damaged beyond repair"))
            scan(file("damaged.png"))
            expectImageError("Couldn't read the QR code")
        }

        function test_unopenableImageShowsError() {
            verify(fake.writeBrokenPng(file("broken.png")))
            scan(file("broken.png"))
            expectImageError("Couldn't open the image")
        }

        function test_unsupportedFormatShowsError() {
            verify(fake.writeText(file("notes.txt"), "not image bytes"))
            scan(file("notes.txt"))
            expectImageError(unsupportedText())
        }

        // Req. 5.5: shown for 4 seconds.
        function test_imageErrorLastsFourSeconds() {
            verify(fake.writeBlankImage(file("blank4s.png")))
            scan(file("blank4s.png"))
            tryCompare(controlUnderTest, "imageErrorMessage", "No QR code found in the image", 5000)
            wait(3500)
            compare(controlUnderTest.imageErrorMessage, "No QR code found in the image")
            tryCompare(controlUnderTest, "imageErrorMessage", "", 1500)
        }

        // Req. 5.6: another image can be picked while the message shows.
        function test_imageErrorIsNotBlocking() {
            verify(fake.writeBlankImage(file("blank-nb.png")))
            verify(fake.writeQrImage(file("valid-nb.png"), root.address))
            scan(file("blank-nb.png"))
            tryCompare(controlUnderTest, "imageErrorMessage", "No QR code found in the image", 5000)
            const button = findChild(controlUnderTest, "qrUploadImageButton")
            verify(!!button)
            verify(button.visible && button.enabled)
            scan(file("valid-nb.png"))
            tryCompare(tagSpy, "count", 1, 5000)
            compare(controlUnderTest.imageErrorMessage, "")
        }

        // Req. 5.6: the camera keeps scanning while the message shows.
        function test_cameraScansDuringImageError() {
            verify(fake.writeBlankImage(file("blank-cam.png")))
            scan(file("blank-cam.png"))
            tryCompare(controlUnderTest, "imageErrorMessage", "No QR code found in the image", 5000)
            const output = findChild(controlUnderTest, "qrCaptureVideoOutput")
            verify(!!output)
            verify(fake.pushQr(output.videoSink, root.address, 640, 640))
            tryCompare(tagSpy, "count", 1, 5000)
            compare(controlUnderTest.imageErrorMessage, "")
        }

        // One result per session.
        function test_imageIgnoredAfterCameraSuccess() {
            const output = findChild(controlUnderTest, "qrCaptureVideoOutput")
            verify(fake.pushQr(output.videoSink, root.address, 640, 640))
            tryCompare(tagSpy, "count", 1, 5000)
            verify(fake.writeQrImage(file("after.png"), root.address))
            scan(file("after.png"))
            wait(1500)
            compare(tagSpy.count, 1)
        }

        // reset() starts a new session: the previous one's image is dropped.
        function test_resetDropsPendingImage() {
            verify(fake.writeQrImage(file("reset.png"), root.address))
            scan(file("reset.png"))
            controlUnderTest.reset()
            wait(1500)
            compare(tagSpy.count, 0)
            compare(controlUnderTest.imageErrorMessage, "")
            scan(file("reset.png")) // the new session scans normally
            tryCompare(tagSpy, "count", 1, 5000)
        }

        // Hiding the scanner drops its image, also once it is shown again.
        function test_hiddenScannerDropsPendingImage() {
            verify(fake.writeQrImage(file("hidden.png"), root.address))
            scan(file("hidden.png"))
            controlUnderTest.visible = false
            wait(500)
            controlUnderTest.visible = true
            wait(1500)
            compare(tagSpy.count, 0)
        }

        // A failure for a dropped image shows nothing either.
        function test_resetDropsPendingImageError() {
            verify(fake.writeBlankImage(file("reset-blank.png")))
            scan(file("reset-blank.png"))
            controlUnderTest.reset()
            wait(1500)
            compare(controlUnderTest.imageErrorMessage, "")
        }

        function imageButton() {
            const button = findChild(controlUnderTest, "qrUploadImageButton")
            verify(!!button)
            verify(button.visible && button.enabled)
            compare(button.icon.name, "select-image")
            return button
        }

        // In the camera view: left edge, vertically centred on the camera
        // picker at the right edge.
        function test_imageButtonAlignedWithCameraPicker() {
            const button = imageButton()
            const view = findChild(controlUnderTest, "statusQrCodeScanner")
            const picker = findChild(view, "qrCameraComboBox")
            verify(!!view && !!picker)
            const pos = button.mapToItem(view, 0, 0)
            compare(pos.x, 12)
            const pickerPos = picker.mapToItem(view, 0, 0)
            compare(pos.y + button.height / 2, pickerPos.y + picker.height / 2)
            // styled like the picker: its background and transparency
            compare(button.width, 40)
            compare(button.height, 40)
            compare(String(button.normalColor), String(button.Theme.palette.baseColor2))
            compare(button.opacity, picker.opacity)
        }

        // On the camera access screen: bottom-left, so an image can still
        // be scanned without the camera.
        function test_imageButtonAtBottomLeftWithoutCameraAccess() {
            controlUnderTest.cameraAccess = deniedAccess
            const button = imageButton()
            compare(button.width, 40)
            compare(button.height, 40)
            compare(String(button.normalColor), String(button.Theme.palette.baseColor5))
            const area = findChild(controlUnderTest, "qrCameraArea")
            verify(!!area)
            const pos = button.mapToItem(area, 0, 0)
            compare(pos.x, 10)
            compare(pos.y + button.height, area.height - 10)
        }

        // The picker offers the formats the error names, in both cases: file
        // dialogs on case-sensitive file systems hide IMG_0001.JPG otherwise.
        function test_pickerFiltersBothCases() {
            const picker = findChild(controlUnderTest, "qrImageFileDialog")
            const decoder = findChild(controlUnderTest, "qrImageDecoder")
            verify(!!picker && !!decoder)
            const filters = picker.nameFilters.join(" ")
            const exts = ["jpg", "jpeg", "png"].concat(decoder.heicSupported ? ["heic", "heif"] : [])
            for (const ext of exts) {
                verify(filters.includes("*." + ext), ext)
                verify(filters.includes("*." + ext.toUpperCase()), ext.toUpperCase())
            }
            if (!decoder.heicSupported)
                verify(!filters.toLowerCase().includes("heic"))
        }

        function test_cancelledPickerDoesNothing() {
            const picker = findChild(controlUnderTest, "qrImageFileDialog")
            verify(!!picker)
            picker.rejected()
            wait(300)
            compare(controlUnderTest.state, StatusQrCodeScanner.State.None)
            compare(controlUnderTest.imageErrorMessage, "")
            compare(tagSpy.count, 0)
        }

        // Without camera access (desktops without a camera, a denied prompt)
        // the image path is the way to scan.
        function test_uploadWorksWithoutCameraAccess() {
            controlUnderTest.cameraAccess = deniedAccess
            const button = findChild(controlUnderTest, "qrUploadImageButton")
            verify(!!button)
            verify(button.visible && button.enabled)
            verify(fake.writeQrImage(file("nocam.png"), root.address))
            scan(file("nocam.png"))
            tryCompare(tagSpy, "count", 1, 5000)
        }
    }
}
