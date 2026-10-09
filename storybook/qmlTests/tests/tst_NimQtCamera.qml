import QtQuick
import QtTest

// Verifies that Storybook hosts the nim-qtcamera library the same way the app
// does. FrameTap is created with Qt.createQmlObject so this file still loads
// (and skips) when Storybook is built without Nim libraries.
TestCase {
    id: root

    name: "NimQtCamera"
    when: windowShown

    function createTap(name) {
        return Qt.createQmlObject(`
            import QtQuick
            import NimQtCamera 1.0
            FrameTap {}`, root, name)
    }

    function init() {
        if (typeof nimQtCameraBackend === "undefined")
            skip("Storybook built without Nim libraries")
    }

    function test_frameTapAvailable() {
        const tap = createTap("tap")
        verify(tap.handle > 0, "tap has a backend handle")
        compare(tap.maxFps, 5)
        compare(tap.framesPulled, 0)
        tap.enabled = false
        tap.destroy()
    }

    function test_createDestroyRepeatedly() {
        const baseline = nimQtCameraBackend.tapCount()
        let last = 0
        for (let i = 0; i < 20; ++i) {
            const tap = createTap("tap" + i)
            verify(tap.handle > last, "fresh handle each time")
            last = tap.handle
            compare(nimQtCameraBackend.tapCount(), baseline + 1)
            tap.destroy()
            wait(0)
            compare(nimQtCameraBackend.tapCount(), baseline, "destroyed tap is released")
        }
    }
}
