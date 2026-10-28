import QtQuick
import QtTest

import StatusQ.Components

Item {
    id: root

    width: 200
    height: 200

    Component {
        id: contentComponent

        // a red frame over white, faded by the effect's parameters
        Rectangle {
            id: content

            property real fadeTop
            property real fadeBottom
            property real fadeLeft
            property real fadeRight
            property real topOpacity

            width: 100
            height: 100
            color: "red"

            layer.enabled: true
            layer.effect: StatusEdgeFadeEffect {
                topFade: content.fadeTop
                bottomFade: content.fadeBottom
                leftFade: content.fadeLeft
                rightFade: content.fadeRight
                topEdgeOpacity: content.topOpacity
            }
        }
    }

    TestCase {
        name: "StatusEdgeFadeEffect"
        when: windowShown

        function grab(properties) {
            if (root.GraphicsInfo.api === GraphicsInfo.Software)
                skip("ShaderEffect does not run under the software renderer")

            const content = createTemporaryObject(contentComponent, root, properties)
            verify(!!content)
            return grabImage(content)
        }

        // how much of the red is left, over the white window: 1 = all red
        function redness(color) {
            return 1 - color.g
        }

        function test_fadesOverTheGivenLength() {
            const img = grab({ fadeTop: 20 })

            verify(redness(img.pixel(50, 0)) < 0.05, "transparent at the edge")
            const mid = redness(img.pixel(50, 10))
            verify(mid > 0.3 && mid < 0.7, `half way in the middle of the fade (${mid})`)
            verify(redness(img.pixel(50, 25)) > 0.95, "opaque past the fade")
            verify(redness(img.pixel(50, 99)) > 0.95, "the other edge is untouched")
        }

        function test_easesLikeTheMultiEffectMask() {
            const img = grab({ fadeTop: 40 })

            // smoothstep of a linear ramp: a quarter of the way in gives
            // 0.156, not 0.25
            const quarter = redness(img.pixel(50, 10))
            verify(quarter > 0.08 && quarter < 0.22, `eased (${quarter})`)
        }

        function test_eachEdge() {
            const img = grab({ fadeBottom: 20, fadeLeft: 20, fadeRight: 20 })

            verify(redness(img.pixel(50, 99)) < 0.1, "bottom faded")
            verify(redness(img.pixel(0, 50)) < 0.1, "left faded")
            verify(redness(img.pixel(99, 50)) < 0.1, "right faded")
            verify(redness(img.pixel(50, 0)) > 0.95, "top untouched")
            verify(redness(img.pixel(50, 50)) > 0.95, "centre untouched")
        }

        function test_edgeOpacityOneMeansNoFade() {
            const img = grab({ fadeTop: 20, topOpacity: 1 })

            verify(redness(img.pixel(50, 0)) > 0.95)
            verify(redness(img.pixel(50, 10)) > 0.95)
        }
    }
}
