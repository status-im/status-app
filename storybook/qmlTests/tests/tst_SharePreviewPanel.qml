import QtQuick
import QtTest

import mainui

Item {
    id: root

    width: 500
    height: 600

    // Self-contained 1x1 PNG standing in for the cached file paths the share
    // intake delivers (no filesystem dependency, no Image load warnings).
    readonly property string sampleImage:
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="

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
            verify(textArea)
            verify(sendButton)

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

        function test_thumbnailsHiddenForTextShare() {
            const preview = createPreview()
            const thumbnails = findChild(preview, "sharePreviewThumbnailsList")
            verify(thumbnails)

            compare(thumbnails.count, 0)
            verify(!thumbnails.visible)
        }

        function test_thumbnailShownPerSharedImage() {
            const preview = createPreview()
            const thumbnails = findChild(preview, "sharePreviewThumbnailsList")
            verify(thumbnails)

            preview.imagePaths = [root.sampleImage, root.sampleImage, root.sampleImage]
            waitForRendering(preview)

            compare(thumbnails.count, 3)
            verify(thumbnails.visible)
            const thumbnail = findChild(thumbnails, "sharePreviewThumbnail")
            verify(thumbnail)
            tryCompare(thumbnail, "status", Image.Ready)
        }

        function test_sendEnabledWithImagesAndBlankCaption() {
            const preview = createPreview()
            const textArea = findChild(preview, "sharePreviewTextArea")
            const sendButton = findChild(preview, "sharePreviewSendButton")
            verify(textArea)
            verify(sendButton)

            preview.imagePaths = [root.sampleImage]
            textArea.text = ""
            verify(sendButton.enabled)

            mouseClick(sendButton)

            compare(sendRequestedSpy.count, 1)
            compare(sendRequestedSpy.signalArguments[0][0], "")
        }

        function test_sendWithImagesEmitsEditedCaption() {
            const preview = createPreview()
            const textArea = findChild(preview, "sharePreviewTextArea")
            const sendButton = findChild(preview, "sharePreviewSendButton")
            verify(textArea)
            verify(sendButton)

            preview.imagePaths = [root.sampleImage, root.sampleImage]
            textArea.text = "Gallery caption"
            mouseClick(sendButton)

            compare(sendRequestedSpy.count, 1)
            compare(sendRequestedSpy.signalArguments[0][0], "Gallery caption")
        }
    }
}
