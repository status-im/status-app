import QtQuick
import QtTest

import StatusQ.Components

// Hover reporting must be exclusive to real pointing devices. A touch tap makes Qt synthesize
// a mouse move ("core pointer"), which used to set `hovered` and pop up the hover-driven
// quick-actions context menu on top of the long-press one.
Item {
    id: root
    width: 600
    height: 400

    Component {
        id: componentUnderTest

        StatusMessage {
            width: 500
            messageId: "m1"
            messageDetails: StatusMessageDetails {
                messageText: "hello"
                unparsedText: "hello"
            }
        }
    }

    SignalSpy {
        id: hoverSpy
        signalName: "hoverChanged"
    }

    TestCase {
        id: testCase
        name: "StatusMessageHover"
        when: windowShown

        // Touch taps are expected NOT to produce a hover. Waiting for a fixed amount of time
        // would only make the test slow and flaky, so instead a subsequent real mouse hover is
        // used as a synchronisation point: once it has been reported, any (synthesized) hover
        // from the preceding touch tap would certainly have been delivered as well.
        function syncOnMouseHover(control) {
            mouseMove(control, 50, 10)
            tryVerify(() => control.hovered, 5000, "the mouse hover was never delivered")
        }

        function createControl() {
            const control = createTemporaryObject(componentUnderTest, root)
            verify(control)
            hoverSpy.target = control
            hoverSpy.clear()
            return control
        }

        // A mouse move over the message reports hovered=true.
        function test_mouseHoverEmitsHoverChanged() {
            const control = createControl()

            mouseMove(control, 50, 10)
            tryVerify(() => hoverSpy.count > 0, 2000, "mouse hover must emit hoverChanged")
            compare(hoverSpy.signalArguments[hoverSpy.count - 1][0], "m1")
            compare(hoverSpy.signalArguments[hoverSpy.count - 1][1], true)

            // Move away again: hover ends.
            mouseMove(control, 50, root.height - 1)
            tryCompare(control, "effectiveHovered", false)
        }

        // A touch tap must not report hover at all (the synthesized mouse move is suppressed).
        // Note the synthesized hover latches on and does not clear by itself, so this checks that
        // hover never pulses true at any point, not merely that it settled back to false.
        function test_touchTapDoesNotEmitHoverChanged() {
            const control = createControl()

            const touch = touchEvent(control)
            touch.press(0, control, 50, 10).commit()
            touch.release(0, control, 50, 10).commit()
            syncOnMouseHover(control)

            compare(hoverSpy.count, 0, "touch tap must not emit hoverChanged")
            compare(control.effectiveHovered, false)
        }

        // The suppression must not be sticky: a real mouse hover after a touch tap still works.
        function test_mouseHoverAfterTouchTapStillWorks() {
            const control = createControl()

            const touch = touchEvent(control)
            touch.press(0, control, 50, 10).commit()
            touch.release(0, control, 50, 10).commit()

            // Leave the message, then come back with the mouse. (That the tap itself reports no
            // hover is covered by `test_touchTapDoesNotEmitHoverChanged`.)
            mouseMove(control, 50, root.height - 1)
            tryVerify(() => !control.hovered, 5000, "the mouse never left the message")
            mouseMove(control, 50, 10)
            tryVerify(() => hoverSpy.count > 0, 2000, "mouse hover after a touch tap must work")
            compare(hoverSpy.signalArguments[hoverSpy.count - 1][1], true)
        }
    }
}
