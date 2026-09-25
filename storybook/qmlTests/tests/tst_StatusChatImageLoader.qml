import QtQuick
import QtTest

import shared.status

Item {
    id: root

    width: 600
    height: 600

    readonly property url stillSource: Qt.resolvedUrl("../../testData/image_example.png")
    readonly property url gifSource: Qt.resolvedUrl("../../testData/image_example.gif")

    Component {
        id: componentUnderTest

        StatusChatImageLoader {
            imageWidth: 300
        }
    }

    TestCase {
        name: "StatusChatImageLoader"
        when: windowShown

        function decodeWidthFor(imageWidth) {
            return Math.ceil(imageWidth * Screen.devicePixelRatio / 128) * 128
        }

        function test_stillBuildsOnlyABoundedImage() {
            const control = createTemporaryObject(componentUnderTest, root, { source: root.stillSource })
            verify(control)
            tryVerify(() => control.imageAlias !== null)
            verify(control.imageAlias instanceof Image)
            verify(!(control.imageAlias instanceof AnimatedImage))
            compare(control.imageAlias.sourceSize.width, decodeWidthFor(300))
            compare(control.imageAlias.cache, false)
            tryCompare(control, "imageLoaded", true)
            verify(control.imageAlias.width <= 300)
        }

        function test_gifBuildsOnlyABoundedAnimatedImage() {
            const control = createTemporaryObject(componentUnderTest, root,
                                                  { source: root.gifSource, cacheImage: true })
            verify(control)
            tryVerify(() => control.imageAlias !== null)
            verify(control.imageAlias instanceof AnimatedImage)
            compare(control.imageAlias.sourceSize.width, decodeWidthFor(300))
            compare(control.imageAlias.cache, true)
            tryCompare(control, "imageLoaded", true)
        }

        function test_decodeWidthIsSteppedAndFollowsAsynchronous() {
            const control = createTemporaryObject(componentUnderTest, root,
                                                  { source: root.stillSource, asynchronous: false })
            verify(control)
            verify(control.imageAlias)
            compare(control.imageAlias.asynchronous, false)
            compare(control.imageAlias.sourceSize.width, decodeWidthFor(300))

            control.imageWidth = 310
            compare(control.imageAlias.sourceSize.width, decodeWidthFor(310))
            compare(decodeWidthFor(310) % 128, 0)
        }
    }
}
