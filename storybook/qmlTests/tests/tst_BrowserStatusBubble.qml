import QtQuick
import QtTest

import AppLayouts.Browser.controls

Item {
    id: root

    width: 400
    height: 200

    Component {
        id: bubbleComponent

        StatusBubble {}
    }

    TestCase {
        name: "BrowserStatusBubble"
        when: windowShown

        function test_show_displaysHoveredUrl() {
            const bubble = createTemporaryObject(bubbleComponent, root)
            bubble.show("https://status.app/api/download/windows")

            compare(bubble.text, "https://status.app/api/download/windows")
            verify(bubble.visible)
        }

        function test_hide_clearsAtOnce() {
            const bubble = createTemporaryObject(bubbleComponent, root)
            bubble.show("https://status.app/")
            bubble.hide()

            compare(bubble.text, "")
            verify(!bubble.visible)
        }
    }
}
