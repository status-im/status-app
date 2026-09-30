import QtQuick
import QtTest

import shared.controls.delegates

Item {
    id: root

    readonly property string gifSource: Qt.resolvedUrl("../../testData/image_example.gif")

    Component {
        id: componentUnderTest

        LinkPreviewGifDelegate {
            link: root.gifSource
            playAnimation: false
            isOnline: true
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

        function test_loadedGifKeepsMessagePreviewSize() {
            const control = createTemporaryObject(componentUnderTest, root)
            verify(control)
            tryVerify(() => control.imageAlias !== null)
            tryCompare(control.imageAlias, "status", Image.Ready)
            verify(control.implicitWidth > 0)
            verify(control.implicitHeight > 0)
        }
    }
}