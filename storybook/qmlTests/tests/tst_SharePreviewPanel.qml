import QtQuick
import QtTest

import mainui

Item {
    id: root

    width: 500
    height: 600

    Component {
        id: testComponent

        SharePreviewPanel {
            anchors.fill: parent
            destinationName: "Design crew"
            text: "Look at this https://example.com/article"
        }
    }

    SignalSpy {
        id: sendRequestedSpy
        signalName: "sendRequested"
    }

    SignalSpy {
        id: backRequestedSpy
        signalName: "backRequested"
    }

    SignalSpy {
        id: cancelRequestedSpy
        signalName: "cancelRequested"
    }

    TestCase {
        name: "SharePreviewPanelTest"
        when: windowShown

        function init() {
            sendRequestedSpy.clear()
            backRequestedSpy.clear()
            cancelRequestedSpy.clear()
        }

        function createPreview() {
            const preview = createTemporaryObject(testComponent, root)
            sendRequestedSpy.target = preview
            backRequestedSpy.target = preview
            cancelRequestedSpy.target = preview
            waitForRendering(preview)
            return preview
        }

        function test_sendEmitsEditedText() {
            const preview = createPreview()
            const textArea = findChild(preview, "sharePreviewTextArea")
            const sendButton = findChild(preview, "sharePreviewSendButton")
            verify(textArea)
            verify(sendButton)

            compare(textArea.text, "Look at this https://example.com/article")
            verify(sendButton.enabled)

            textArea.text = "Edited before sending"
            mouseClick(sendButton)

            compare(sendRequestedSpy.count, 1)
            compare(sendRequestedSpy.signalArguments[0][0], "Edited before sending")
        }

        function test_sendDisabledOnBlankText() {
            const preview = createPreview()
            const textArea = findChild(preview, "sharePreviewTextArea")
            const sendButton = findChild(preview, "sharePreviewSendButton")

            textArea.text = "   "
            verify(!sendButton.enabled)

            mouseClick(sendButton)
            compare(sendRequestedSpy.count, 0)
        }

        function test_backEmitsIntent() {
            const preview = createPreview()
            const backButton = findChild(preview, "sharePreviewBackButton")
            verify(backButton)

            mouseClick(backButton)

            compare(backRequestedSpy.count, 1)
            compare(sendRequestedSpy.count, 0)
        }

        function test_cancelEmitsIntent() {
            const preview = createPreview()
            const cancelButton = findChild(preview, "sharePreviewCancelButton")
            verify(cancelButton)

            mouseClick(cancelButton)

            compare(cancelRequestedSpy.count, 1)
            compare(sendRequestedSpy.count, 0)
        }
    }
}
