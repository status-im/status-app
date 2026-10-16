import QtQuick
import QtTest

import Storybook.Testing

// The Storybook page logs what QrScanner's tagFound delivers to "Events".
Item {
    id: root

    width: 600
    height: 600

    FakeVideoSource {
        id: fakeSource
    }

    TestCase {
        name: "StatusQrCodeScannerPage"
        when: windowShown

        function test_tagFoundIsLoggedToEvents() {
            const component = Qt.createComponent(Qt.resolvedUrl("../../pages/StatusQrCodeScannerPage.qml"))
            compare(component.status, Component.Ready, component.errorString())
            const page = createTemporaryObject(component, root, { width: 600, height: 600 })
            verify(!!page)

            const output = findChild(page, "qrCaptureVideoOutput")
            verify(!!output)
            const logs = page.contentData.find(o => o && o.logText !== undefined)
            verify(!!logs, "page has no Logs")

            verify(fakeSource.pushQr(output.videoSink, "logged-tag", 640, 640))
            tryVerify(() => logs.logText.includes("tagFound") && logs.logText.includes("logged-tag"),
                      5000, "tagFound not logged")
        }
    }
}
