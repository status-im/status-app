import QtQuick
import QtQuick.Window
import QtTest

import "../../../ui/app/AppLayouts/Wallet/views"

/*
 Checks what the loading graph actually draws. The offscreen QPA platform has
 no RHI backend to compile and run shaders with, so every test is skipped
 there; run it with a real window (no QT_QPA_PLATFORM=offscreen).
*/
Item {
    id: root
    width: 400
    height: 300

    Component {
        id: graphComp

        Rectangle {
            width: 300
            height: 150
            color: "#0000ff"

            LoadingGraphView {
                anchors.fill: parent
                active: true
            }
        }
    }

    // many sweeping graphs, to give the render thread work while they are removed
    Component {
        id: gridComp

        Loader {
            active: false
            sourceComponent: Grid {
                columns: 6

                Repeater {
                    model: 120

                    LoadingGraphView {
                        width: 60
                        height: 30
                        active: true
                    }
                }
            }
        }
    }

    // ticks on the animation clock, so removals land right after a sync
    Timer {
        id: toggler

        property Loader target: null
        property int toggles: 0

        interval: 150
        repeat: true
        onTriggered: {
            target.active = !target.active
            ++toggles
        }
    }

    TestCase {
        name: "LoadingGraphViewRendering"
        when: windowShown

        function init() {
            if (Qt.platform.pluginName === "offscreen")
                skip("shaders are not run on the offscreen platform")
        }

        function isBackground(c) {
            return c.r < 0.05 && c.g < 0.05 && c.b > 0.95
        }

        // summed brightness of the drawn graph
        function graphBrightness(image) {
            let sum = 0
            for (let y = 0; y < image.height; y += 2) {
                for (let x = 0; x < image.width; x += 2) {
                    const c = image.pixel(x, y)
                    sum += c.r + c.g + c.b
                }
            }
            return sum
        }

        function test_draws_below_the_line_with_a_moving_band() {
            const frame = createTemporaryObject(graphComp, root)
            verify(!!frame)
            waitForRendering(frame)

            // the mask texture may arrive a frame later
            let image = null
            let scale = 1
            tryVerify(() => {
                image = grabImage(frame)
                scale = image.width / frame.width
                return !isBackground(image.pixel(frame.width / 2 * scale, (frame.height - 3) * scale))
            }, 3000, "below the graph line must be drawn")
            verify(isBackground(image.pixel(2 * scale, 2 * scale)),
                   "above the graph line must stay empty")

            // tryVerify evaluates once more at the end
            const first = graphBrightness(image)
            let changed = false
            tryVerify(() => {
                changed = changed || Math.abs(graphBrightness(grabImage(frame)) - first) > 1
                return changed
            }, 3000, "the sweep band must change the graph in some frame")
        }

        function test_graphs_can_leave_the_window_while_sweeping() {
            toggler.target = createTemporaryObject(gridComp, root)
            verify(!!toggler.target)

            toggler.toggles = 0
            toggler.start()
            tryVerify(() => toggler.toggles >= 60, 30000)
            toggler.stop()
        }
    }
}
