import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtTest

import StatusQ
import StatusQ.Components

Item {
    id: root
    width: 200
    height: 200

    Component {
        id: loadingComp
        LoadingComponent {
            width: 120
            height: 16
            radius: 4
        }
    }

    TestCase {
        name: "LoadingComponent"
        when: windowShown

        function descendants(item) {
            let result = []
            const stack = [item]
            while (stack.length) {
                const current = stack.pop()
                result.push(current)
                const kids = current.children ?? []
                for (let i = 0; i < kids.length; ++i)
                    stack.push(kids[i])
            }
            return result
        }

        function tileOf(comp) {
            return descendants(comp).find(o => o instanceof SkeletonTileItem)
        }

        function init() {
            failOnWarning(/.*/)
        }

        function test_uses_no_animator_objects() {
            const comp = createTemporaryObject(loadingComp, root)
            verify(!!comp)

            verify(!!tileOf(comp), "the placeholder must be a skeleton tile")
            verify(!findChild(comp, "shimmerAnimator"),
                   "the sweep must run on the scene graph side")
        }

        function test_no_offscreen_render_passes() {
            const comp = createTemporaryObject(loadingComp, root)
            verify(!!comp)

            for (const item of descendants(comp)) {
                verify(!(item instanceof MultiEffect), "MultiEffect found")
                verify(!(item instanceof ShaderEffectSource),
                       "ShaderEffectSource found")
                verify(!(item.layer && item.layer.enabled),
                       `layer enabled on ${item}`)
            }
        }

        function test_shape_follows_radius_and_size() {
            const comp = createTemporaryObject(loadingComp, root, {radius: 8})
            verify(!!comp)

            const tile = tileOf(comp)
            verify(!!tile, "the placeholder must be a skeleton tile")
            compare(tile.radius, 8)
            compare(tile.width, 120)
            compare(tile.height, 16)

            comp.radius = 2
            comp.width = 60
            comp.height = 30
            compare(tile.radius, 2)
            compare(tile.width, 60)
            compare(tile.height, 30)
        }
    }
}
