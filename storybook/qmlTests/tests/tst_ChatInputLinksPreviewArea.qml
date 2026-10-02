import QtQuick
import QtTest

import Models
import shared.controls.chat

Item {
    id: root
    width: 800
    height: 200

    ListModel { id: emptyModel }

    LinkPreviewModel { id: mockedLinkPreviewModel }

    Component {
        id: componentUnderTest

        ChatInputLinksPreviewArea {
            width: 600
            imagePreviewArray: []
            linkPreviewModel: emptyModel
            showLinkPreviewSettings: false
            paymentRequestModel: emptyModel
        }
    }

    TestCase {
        name: "ChatInputLinksPreviewArea"
        when: windowShown

        function createArea(props = {}) {
            const area = createTemporaryObject(componentUnderTest, root, props)
            verify(area)
            return area
        }

        function test_showLinkPreviewSettings_makesAreaNonEmpty() {
            const area = createArea({ showLinkPreviewSettings: true })
            compare(area.hasContent, true)
            verify(findChild(area, "titleText"))
        }

        function test_linkPreviewModel_showsMiniCards() {
            const area = createArea({ linkPreviewModel: mockedLinkPreviewModel })
            compare(area.hasContent, true)
            verify(findChild(area, "linkPreviewSubtitleText"))
        }

        function test_imagePreviewArray_contributesToHasContent() {
            const area = createArea({ imagePreviewArray: ["https://example.com/preview.png"] })
            compare(area.hasContent, true)
        }
    }
}
