import QtQuick
import QtTest

import shared.controls.chat
import utils

Item {
    id: root

    Component {
        id: componentUnderTest

        LinkPreviewCard {
            type: Constants.LinkPreviewType.Standard
            linkData {
                title: "Example title"
                description: "Example description"
                domain: "www.example.com"
            }
        }
    }

    TestCase {
        name: "LinkPreviewCard"
        when: windowShown

        function test_standardLink_showsTitle() {
            const card = createTemporaryObject(componentUnderTest, root)
            verify(card)

            const title = findChild(card, "linkPreviewTitle")
            verify(title)
            compare(title.text, "Example title")
        }
    }
}
