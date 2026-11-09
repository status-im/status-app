import QtQuick
import QtQuick.Window
import QtTest

import StatusQ.Controls

/*
 Checks what the ripple actually draws. The offscreen QPA platform has no RHI
 backend to compile and run shaders with, so every test is skipped there; run
 it with a real window (no QT_QPA_PLATFORM=offscreen).
*/
Item {
    id: root
    width: 400
    height: 200

    Component {
        id: rippleComp

        Rectangle {
            readonly property alias ripple: ripple

            width: 200
            height: 100
            color: "#0000ff"

            StatusRipple {
                id: ripple
                anchors.fill: parent
                radius: 20
                color: "#ffffff"
                maxOpacity: 1
                expandDuration: 4000
            }
        }
    }

    // many expanding ripples, to give the render thread work while they are removed
    Component {
        id: gridComp

        Loader {
            active: false
            sourceComponent: Grid {
                columns: 10

                Repeater {
                    model: 300

                    StatusRipple {
                        width: 36
                        height: 16
                        color: "#ffffff"
                        expandDuration: 1000
                        Component.onCompleted: press(0, 0)
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

    SignalSpy {
        id: frameSpy
        target: root.Window.window
        signalName: "frameSwapped"
    }

    TestCase {
        name: "StatusRippleRendering"
        when: windowShown

        function init() {
            if (Qt.platform.pluginName === "offscreen")
                skip("shaders are not run on the offscreen platform")
        }

        // white circle over the blue background
        function lit(image, scale, x, y) {
            const c = image.pixel(Math.round(x * scale), Math.round(y * scale))
            return c.r + c.g + c.b > 2
        }

        function test_circle_grows_from_the_press_point() {
            const frame = createTemporaryObject(rippleComp, root)
            verify(!!frame)
            const ripple = frame.ripple
            waitForRendering(frame)

            ripple.press(30, 50)

            let nearBeforeFar = false
            tryVerify(() => {
                const image = grabImage(frame)
                const scale = image.width / frame.width
                const near = lit(image, scale, 40, 50)
                const far = lit(image, scale, 180, 50)
                nearBeforeFar = nearBeforeFar || (near && !far)
                return near && far
            }, 8000, "the circle must reach the far side")
            verify(nearBeforeFar, "the circle must cover the press point before the far side")

            const image = grabImage(frame)
            verify(!lit(image, image.width / frame.width, 1, 1),
                   "the rounded corner must clip the circle")

            ripple.release()
            tryCompare(ripple, "visible", false)
        }

        function test_requests_no_frames_while_held() {
            const frame = createTemporaryObject(rippleComp, root)
            verify(!!frame)
            const ripple = frame.ripple
            waitForRendering(frame)

            frameSpy.clear()
            ripple.press(30, 50)
            tryVerify(() => frameSpy.count > 3, 2000,
                      "an expanding ripple must keep the window rendering")
            tryVerify(() => Math.abs(ripple.rippleRadius - ripple.endRadius) < 0.5, 8000,
                      "the ripple must reach its end radius")
            // let the frames already in flight finish
            wait(100)
            frameSpy.clear()
            wait(300)
            verify(frameSpy.count <= 2,
                   `a held ripple must not request frames, got ${frameSpy.count}`)

            ripple.release()
            tryCompare(ripple, "visible", false)
            compare(ripple.rippleRadius, 0)
        }

        function test_ripples_can_leave_the_window_while_expanding() {
            toggler.target = createTemporaryObject(gridComp, root)
            verify(!!toggler.target)

            toggler.toggles = 0
            toggler.start()
            tryVerify(() => toggler.toggles >= 60, 30000)
            toggler.stop()
        }
    }
}
