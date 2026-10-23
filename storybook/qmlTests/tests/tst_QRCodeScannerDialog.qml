import QtQuick
import QtTest

import StatusQ.Components

import Storybook.Testing

import shared.popups

Item {
    id: root

    width: 1200
    height: 1000

    readonly property string address: "0x1234567890abcdef1234567890abcdef12345678"
    readonly property string sampleLink: "https://example.com/docs"
    readonly property string sampleStatusLink: "https://status.app/c/abc"
    readonly property string sampleWalletConnectUri: "wc:abcdef@2?relay-protocol=irn&symKey=aabb"

    Component {
        id: componentUnderTest

        QRCodeScannerDialog {}
    }

    property QRCodeScannerDialog controlUnderTest: null

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

    FakeVideoSource {
        id: fake
    }

    SignalSpy {
        id: tagSpy
        signalName: "tagFound"
    }

    TestCase {
        name: "QRCodeScannerDialog"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            scanner().cameraAccess = grantedAccess
            tagSpy.target = controlUnderTest
            tagSpy.clear()
        }

        function scanner() {
            const s = findChild(controlUnderTest.contentItem, "qrCodeScanner")
            verify(!!s)
            return s
        }

        function videoSink() {
            let output = null
            tryVerify(() => {
                output = findChild(controlUnderTest, "qrCaptureVideoOutput")
                return !!output && !!output.videoSink
            })
            return output.videoSink
        }

        function scanQr(text) {
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            verify(fake.pushQr(videoSink(), text, 640, 640))
        }

        function cleanup() {
            root.height = 1000
        }

        function rows() {
            const r = findChild(controlUnderTest.contentItem, "qrScannerInfoRows")
            verify(!!r)
            return r
        }

        function verifyContentFits() {
            const view = controlUnderTest.contentItem
            const r = rows()
            verify(r.height > 0)
            const bottom = r.mapToItem(view, 0, r.height).y
            verify(bottom <= view.height + 0.5,
                   `rows end at ${bottom}, content is ${view.height} tall`)
        }

        function test_infoRowsHiddenWithoutCameraAccess() {
            scanner().cameraAccess = deniedAccess
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            compare(rows().visible, false)
        }

        function test_infoRowsHiddenWhenPermissionDenied() {
            controlUnderTest.cameraPermissionDenied = true
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            compare(rows().visible, false)
        }

        function test_infoRowsShownWithCamera() {
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            compare(rows().visible, true)
        }

        function test_reopenStartsAFreshSession() {
            tagSpy.clear()
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            const qrScanner = scanner()

            qrScanner.state = StatusQrCodeScanner.State.Success
            qrScanner.validTagFound(root.address)
            tryCompare(tagSpy, "count", 1, 2000)
            tryCompare(controlUnderTest, "opened", false)

            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            compare(qrScanner.state, StatusQrCodeScanner.State.None)
            qrScanner.validTagFound(root.address)
            tryCompare(tagSpy, "count", 2, 2000)
        }

        function openScanner() {
            tagSpy.clear()
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            return scanner()
        }

        function expectTagFound(tagType, tag) {
            tryCompare(tagSpy, "count", 1, 5000)
            compare(tagSpy.signalArguments[0][0], tagType)
            compare(tagSpy.signalArguments[0][1], tag)
            tryCompare(controlUnderTest, "opened", false)
        }

        function imageUrl(name) {
            const path = fake.tempPath("qrdialog-image-" + name)
            verify(fake.writeQrImage(path, root.address))
            return fake.fileUrl(path)
        }

        function test_closeDuringImageDecodeEmitsNothing() {
            const scanner = openScanner()
            scanner.scanImageFile(imageUrl("close.png"))
            controlUnderTest.close()
            tryCompare(controlUnderTest, "opened", false)
            wait(1500)
            compare(tagSpy.count, 0)
        }

        function test_reopenDropsThePreviousSessionsImage() {
            const scanner = openScanner()
            scanner.scanImageFile(imageUrl("reopen.png"))
            controlUnderTest.close()
            tryCompare(controlUnderTest, "opened", false)
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            wait(1500)
            compare(tagSpy.count, 0)
            compare(scanner.state, StatusQrCodeScanner.State.None)
        }

        readonly property string profileLink:
            "https://status.app/u/iweACg4KDHpRMy4uLlZoNG5OMwM=#zQ3shZnCMtyHdMqqBw3yEGqmzKKNUxvJorDJqMjWPEEVh4nN3"

        function realImage(name) {
            return Qt.resolvedUrl("../../testData/qr/" + name)
        }

        function test_realImageOpensTheProfile_data() {
            return [
                { tag: "straight", file: "profile.png", heic: false },
                { tag: "rotated", file: "profile-angle.png", heic: false },
                { tag: "HEIC", file: "profile-angle.heic", heic: true },
                { tag: "HEIF", file: "profile-angle.heif", heic: true },
                { tag: "PNG named .heic", file: "profile-png-content.heic", heic: false },
            ]
        }

        function test_realImageOpensTheProfile(data) {
            const scanner = openScanner()
            if (data.heic && !findChild(scanner, "qrImageDecoder").heicSupported)
                skip("no HEIC decoder on this platform")
            scanner.scanImageFile(realImage(data.file))
            tryCompare(tagSpy, "count", 1, 5000)
            compare(tagSpy.signalArguments[0][0], QRCodeScannerDialog.TagType.Link)
            compare(tagSpy.signalArguments[0][1], profileLink)
            tryCompare(controlUnderTest, "opened", false)
        }

        function test_realImageCutOffCantBeRead() {
            const scanner = openScanner()
            scanner.scanImageFile(realImage("profile-partial.png"))
            tryCompare(scanner, "imageErrorMessage", "Couldn't read the QR code", 5000)
            compare(tagSpy.count, 0)
            verify(controlUnderTest.opened)
            compare(scanner.state, StatusQrCodeScanner.State.None)
        }

        function test_contentFitsInTallWindow() {
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            verifyContentFits()
        }

        function test_contentFitsInShortWindow_data() {
            return [{ tag: "700", height: 700 }, { tag: "680", height: 680 }]
        }

        function test_contentFitsInShortWindow(data) {
            root.height = data.height
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            verify(!controlUnderTest.bottomSheet)
            tryVerify(() => controlUnderTest.height <= data.height * 0.8 + 1)
            verifyContentFits()
        }

        function test_contentScrollsInTinyWindow_data() {
            return [{ tag: "560", height: 560 }, { tag: "380", height: 380 }]
        }

        function test_contentScrollsInTinyWindow(data) {
            root.height = data.height
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            const view = controlUnderTest.contentItem
            const r = rows()
            tryVerify(() => view.contentHeight > view.height)
            verify(r.mapToItem(view.contentItem, 0, r.height).y <= view.contentHeight + 0.5)
            const scanner = findChild(view, "qrCodeScanner")
            verify(scanner.height >= 200, `scanner squeezed to ${scanner.height}`)
        }

        function test_contentFitsWhenWindowShrinksWhileOpen() {
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)
            root.height = 680
            tryVerify(() => controlUnderTest.height <= 680 * 0.8 + 1)
            verifyContentFits()
        }

        function test_scannedCodeEmitsTagFound_data() {
            return [
                { tag: "address", key: "address", type: QRCodeScannerDialog.TagType.Address },
                { tag: "link", key: "sampleLink", type: QRCodeScannerDialog.TagType.Link },
                { tag: "statusLink", key: "sampleStatusLink", type: QRCodeScannerDialog.TagType.Link },
                { tag: "walletConnect", key: "sampleWalletConnectUri", type: QRCodeScannerDialog.TagType.WCUri },
            ]
        }

        function test_scannedCodeEmitsTagFound(data) {
            const text = root[data.key]
            scanQr(text)
            expectTagFound(data.type, text)
        }

        function test_unreadableCodeSetsError() {
            scanQr("not-a-code")
            const statusScanner = findChild(controlUnderTest, "statusQrCodeScanner")
            tryCompare(statusScanner, "state", StatusQrCodeScanner.State.Error, 5000)
            compare(tagSpy.count, 0)
            compare(controlUnderTest.opened, true)
        }
    }
}
