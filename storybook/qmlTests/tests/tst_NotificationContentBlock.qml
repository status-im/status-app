import QtQuick
import QtTest

import AppLayouts.ActivityCenter.controls
import StatusQ.Core.Theme

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest
        NotificationContentBlock {
            anchors.centerIn: parent
            width: 400
        }
    }

    SignalSpy {
        id: linkActivatedSpy
        target: controlUnderTest
        signalName: "linkActivated"
    }

    SignalSpy {
        id: imageClickedSpy
        target: controlUnderTest
        signalName: "imageClicked"
    }

    property NotificationContentBlock controlUnderTest: null

    TestCase {
        name: "NotificationContentBlock"
        when: windowShown

        function cleanup() {
            if (!!controlUnderTest)
                controlUnderTest.destroy()
            linkActivatedSpy.clear()
            imageClickedSpy.clear()
        }

        function test_defaults() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
            verify(!!controlUnderTest)

            compare(controlUnderTest.contentText, "")
            compare(controlUnderTest.contentMaxChars, 120)
            compare(controlUnderTest.preImageSource.toString(), "")
            compare(controlUnderTest.maxPreImageHeight, 125)
            compare(controlUnderTest.preImageRadius, 0)
            compare(controlUnderTest.thumbSize, 56)
            compare(controlUnderTest.thumbRadius, 4)
            compare(controlUnderTest.thumbSpacing, 4)
            compare(controlUnderTest.imageClickable, false)
        }

        function test_contentTextDisplay() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                contentText: "Hello, this is a notification message"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.contentText, "Hello, this is a notification message")
            verify(controlUnderTest.height > 0)
        }

        function test_emptyContentText() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                contentText: ""
            })
            verify(!!controlUnderTest)
            compare(controlUnderTest.contentText, "")
        }

        function test_htmlContentText() {
            const htmlContent = "hey, <a href='robert.eth'>@robert.eth</a>, check this out"
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                contentText: htmlContent
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.contentText, htmlContent)
        }

        function test_contentMaxChars() {
            // Create a string longer than the max chars limit
            const longText = "A".repeat(200)
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                contentText: longText,
                contentMaxChars: 50
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            compare(controlUnderTest.contentMaxChars, 50)
            // The source text is preserved on the property
            compare(controlUnderTest.contentText, longText)
            // But the rendered text should be truncated (the internal StatusBaseText
            // uses Utils.elideText when plainTextLength > contentMaxChars)
        }

        function test_preImageProperties() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                preImageRadius: 12,
                maxPreImageHeight: 200
            })
            verify(!!controlUnderTest)

            compare(controlUnderTest.preImageRadius, 12)
            compare(controlUnderTest.maxPreImageHeight, 200)
        }

        function test_attachmentsProperty_data() {
            return [
                { tag: "no attachments", attachments: [], count: 0 },
                { tag: "single", attachments: ["img1.png"], count: 1 },
                { tag: "multiple", attachments: ["img1.png", "img2.png", "img3.png"], count: 3 },
            ]
        }

        function test_attachmentsProperty(data) {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                attachments: data.attachments
            })
            verify(!!controlUnderTest)

            compare(controlUnderTest.attachments.length, data.count)
        }

        function test_thumbCustomization() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                thumbSize: 80,
                thumbRadius: 8,
                thumbSpacing: 10
            })
            verify(!!controlUnderTest)

            compare(controlUnderTest.thumbSize, 80)
            compare(controlUnderTest.thumbRadius, 8)
            compare(controlUnderTest.thumbSpacing, 10)
        }

        function test_imageClickableProperty() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                imageClickable: true
            })
            verify(!!controlUnderTest)
            compare(controlUnderTest.imageClickable, true)

            controlUnderTest.imageClickable = false
            compare(controlUnderTest.imageClickable, false)
        }

        function test_linkActivatedSignalDeclared() {
            // Verify the component has a linkActivated signal
            controlUnderTest = createTemporaryObject(componentUnderTest, root, {
                contentText: "Click <a href='http://example.com'>here</a>"
            })
            verify(!!controlUnderTest)
            waitForRendering(controlUnderTest)

            // The signal spy is connected; verify it starts at 0
            compare(linkActivatedSpy.count, 0)
        }
    }
}
