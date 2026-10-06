import QtQuick
import QtTest

import shared.controls.chat

Item {
    id: root

    Component {
        id: componentUnderTest
        LinkPreviewSettingsCard {}
    }

    TestCase {
        name: "LinkPreviewSettingsCard"
        when: windowShown

        function test_showsAskPreviewCopy() {
            const card = createTemporaryObject(componentUnderTest, root)
            verify(card)

            const title = findChild(card, "titleText")
            const subtitle = findChild(card, "subtitleText")
            verify(title)
            verify(subtitle)
            compare(title.text, qsTr("Show link previews?"))
            compare(subtitle.text, qsTr("A preview of your link will be shown here before you send it"))
            verify(findChild(card, "closeLinkPreviewButton"))
        }
    }
}
