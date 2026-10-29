import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtTest

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

        function shaderOf(comp) {
            return descendants(comp).find(o => o instanceof ShaderEffect)
        }

        function init() {
            failOnWarning(/.*/)
        }

        function test_shimmer_absent_when_not_visible() {
            const comp = createTemporaryObject(loadingComp, root, {visible: false})
            verify(!!comp)
            verify(!findChild(comp, "shimmerAnimator"),
                   "no animation object should exist while hidden")
        }

        function test_shimmer_present_and_running_when_visible() {
            skip("shimmer UniformAnimator temporarily disabled (Windows hang investigation)")
            const comp = createTemporaryObject(loadingComp, root, {visible: true})
            verify(!!comp)

            tryVerify(() => !!findChild(comp, "shimmerAnimator"), 1000,
                      "animation object must exist while visible")
            const anim = findChild(comp, "shimmerAnimator")
            compare(anim.running, true, "shimmer must be animating while visible")
            verify(anim instanceof UniformAnimator,
                   "the sweep must be animated on the render thread")
            compare(anim.target, shaderOf(comp))
        }

        function test_shimmer_stops_and_is_removed_when_hidden() {
            skip("shimmer UniformAnimator temporarily disabled (Windows hang investigation)")
            const comp = createTemporaryObject(loadingComp, root, {visible: true})
            verify(!!comp)
            tryVerify(() => !!findChild(comp, "shimmerAnimator"), 1000)

            comp.visible = false

            tryVerify(() => !findChild(comp, "shimmerAnimator"), 1000,
                      "no animation object should linger once hidden")
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

            const shader = shaderOf(comp)
            verify(!!shader, "the placeholder must be drawn by a shader")
            compare(shader.radius, 8)
            compare(shader.width, 120)
            compare(shader.height, 16)

            comp.radius = 2
            comp.width = 60
            comp.height = 30
            compare(shader.radius, 2)
            compare(shader.width, 60)
            compare(shader.height, 30)
        }
    }
}
