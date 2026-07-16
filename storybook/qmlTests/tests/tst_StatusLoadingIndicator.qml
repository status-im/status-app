import QtQuick
import QtTest

import StatusQ.Components

Item {
    id: root
    width: 200
    height: 200

    Component {
        id: spinnerComp
        StatusLoadingIndicator {}
    }

    Component {
        id: hiddenHostComp
        Item {
            visible: false
            property alias spinner: spinner
            StatusLoadingIndicator { id: spinner }
        }
    }

    TestCase {
        name: "StatusLoadingIndicator"
        when: windowShown

        // (2) visible -> the spinner rotation runs.
        function test_spinner_runs_when_visible() {
            const spinner = createTemporaryObject(spinnerComp, root, {visible: true})
            verify(!!spinner)
            const anim = findChild(spinner, "spinnerAnimator")
            verify(!!anim, "the spinner must have a rotation animation")
            compare(anim.running, true, "spinner must rotate while visible")
        }

        // (1) not visible (via hidden ancestor) -> rotation does not run.
        function test_spinner_idle_when_hidden() {
            const host = createTemporaryObject(hiddenHostComp, root)
            verify(!!host)
            const anim = findChild(host.spinner, "spinnerAnimator")
            verify(!!anim)
            compare(anim.running, false, "spinner must not rotate while hidden")
        }

        // (3) becomes hidden -> rotation stops.
        function test_spinner_stops_when_becoming_hidden() {
            const spinner = createTemporaryObject(spinnerComp, root, {visible: true})
            verify(!!spinner)
            const anim = findChild(spinner, "spinnerAnimator")
            verify(!!anim)

            spinner.visible = false
            tryCompare(anim, "running", false, 1000,
                       "spinner must stop rotating once hidden")
        }
    }
}
