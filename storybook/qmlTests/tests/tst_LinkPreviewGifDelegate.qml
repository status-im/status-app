import QtQuick
import QtTest

import shared.controls.delegates

Item {
    id: root

    Component {
        id: componentUnderTest

        LinkPreviewGifDelegate {
            link: "https://media.example.com/animation.gif"
            playAnimation: false
            isOnline: false
        }
    }

    TestCase {
        name: "LinkPreviewGifDelegate"

        function test_accessibleLabel() {
            const control = createTemporaryObject(componentUnderTest, root)
            verify(control)
            compare(control.Accessible.role, Accessible.StaticText)
            compare(control.Accessible.name, "Animated GIF")
        }
    }
}