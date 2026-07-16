import QtQuick
import QtQuick.Controls
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

        // --- Cycle 1: animation lifecycle seam ---

        // (1) not visible -> NO running animation object materialized.
        // The heavy shimmer subtree (gradient + animator) must not exist while
        // the placeholder is hidden, so the render thread can park (no forced
        // 60fps whole-scene repaint).
        function test_shimmer_absent_when_not_visible() {
            const comp = createTemporaryObject(loadingComp, root, {visible: false})
            verify(!!comp)
            verify(!findChild(comp, "shimmerSweep"),
                   "shimmer sweep must not be materialized while hidden")
            verify(!findChild(comp, "shimmerAnimator"),
                   "no animation object should exist while hidden")
        }

        // (2) visible -> shimmer materialized and animating.
        function test_shimmer_present_and_running_when_visible() {
            const comp = createTemporaryObject(loadingComp, root, {visible: true})
            verify(!!comp)

            tryVerify(() => !!findChild(comp, "shimmerSweep"), 1000,
                      "shimmer sweep must be materialized while visible")
            const anim = findChild(comp, "shimmerAnimator")
            verify(!!anim, "animation object must exist while visible")
            compare(anim.running, true, "shimmer must be animating while visible")
        }

        // (3) becomes hidden -> shimmer + animation torn down (placeholder gone).
        function test_shimmer_stops_and_is_removed_when_hidden() {
            const comp = createTemporaryObject(loadingComp, root, {visible: true})
            verify(!!comp)
            tryVerify(() => !!findChild(comp, "shimmerSweep"), 1000)

            comp.visible = false

            tryVerify(() => !findChild(comp, "shimmerSweep"), 1000,
                      "shimmer sweep must be torn down once hidden")
            verify(!findChild(comp, "shimmerAnimator"),
                   "no animation object should linger once hidden")
        }
    }
}
