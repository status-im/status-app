import QtQuick
import QtTest

import StatusQ.Components

Item {
    id: root
    width: 200
    height: 200

    Component {
        id: dotsComp
        StatusDotsLoadingIndicator {
            dotsDiameter: 5
            duration: 500
        }
    }

    // A wrapper hidden via an ancestor: the indicator's own `visible` is
    // effectively false even though it is not set locally.
    Component {
        id: hiddenHostComp
        Item {
            visible: false
            property alias indicator: dots
            StatusDotsLoadingIndicator {
                id: dots
                dotsDiameter: 5
                duration: 500
            }
        }
    }

    TestCase {
        name: "StatusDotsLoadingIndicator"
        when: windowShown

        // (2) visible -> the blink animation runs.
        function test_dots_animate_when_visible() {
            const dots = createTemporaryObject(dotsComp, root, {visible: true})
            verify(!!dots)
            const anim = findChild(dots, "dotBlinkAnimation")
            verify(!!anim, "the dots must have a blink animation")
            compare(anim.running, true, "dot blink must run while visible")
        }

        // (1) not visible (via hidden ancestor) -> NO running blink animation.
        // Guards the regression where Component.onCompleted.start() overrode the
        // running-when-visible binding, leaving hidden dots animating forever.
        function test_dots_do_not_animate_when_hidden() {
            const host = createTemporaryObject(hiddenHostComp, root)
            verify(!!host)
            const anim = findChild(host.indicator, "dotBlinkAnimation")
            verify(!!anim)
            compare(anim.running, false,
                    "dot blink must not run while the indicator is hidden")
        }

        // (3) becomes hidden after being visible -> animation stops.
        function test_dots_stop_when_becoming_hidden() {
            const dots = createTemporaryObject(dotsComp, root, {visible: true})
            verify(!!dots)
            const anim = findChild(dots, "dotBlinkAnimation")
            verify(!!anim)

            dots.visible = false
            tryCompare(anim, "running", false, 1000,
                       "dot blink must stop once the indicator is hidden")
        }
    }
}
