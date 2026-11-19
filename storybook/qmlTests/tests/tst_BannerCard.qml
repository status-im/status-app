import QtQuick
import QtTest

import AppLayouts.Wallet.controls

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: bannerCardComponent

        BannerCard {}
    }

    SignalSpy {
        id: clickedSpy
        signalName: "clicked"
    }

    SignalSpy {
        id: closeSpy
        signalName: "close"
    }

    TestCase {
        id: bannerCardTest

        when: windowShown

        property BannerCard componentUnderTest

        function init() {
            componentUnderTest = createTemporaryObject(bannerCardComponent, root)
            verify(!!componentUnderTest, "Component exists")
            clickedSpy.target = componentUnderTest
            clickedSpy.clear()
            closeSpy.target = componentUnderTest
            closeSpy.clear()
        }

        function test_empty() {
            compare(componentUnderTest.image, "")
            compare(componentUnderTest.title, "")
            compare(componentUnderTest.subTitle, "")
            compare(componentUnderTest.closeEnabled, true)
        }

        function test_geometry() {
            verify(componentUnderTest.height > 0)
            verify(componentUnderTest.width > 0)
        }

        function test_hoverState() {
            compare(componentUnderTest.hovered, false)
            mouseMove(componentUnderTest, componentUnderTest.width / 2, componentUnderTest.height / 2)
            tryCompare(componentUnderTest, "hovered", true)

            const closeButton = findChild(componentUnderTest, "bannerCard_closeButton")
            verify(!!closeButton, "Object exists")
            tryCompare(closeButton, "visible", true)
            verify(closeButton.width > 0)
            verify(closeButton.height > 0)

            mouseMove(closeButton, closeButton.width / 2, closeButton.height / 2)
            tryCompare(componentUnderTest, "hovered", true)
        }

        function test_click() {
            mouseClick(componentUnderTest)
            tryCompare(clickedSpy, "count", 1)

            clickedSpy.clear()

            const closeButton = findChild(componentUnderTest, "bannerCard_closeButton")
            verify(!!closeButton, "Object exists")

            mouseMove(closeButton, closeButton.width / 2, closeButton.height / 2)
            mouseClick(closeButton)
            tryCompare(closeSpy, "count", 1)
            compare(clickedSpy.count, 0)
        }

        function test_touchTap() {
            // Ensure mouse cursor is outside the card before testing touch
            mouseMove(root, root.width - 1, root.height - 1)
            tryCompare(componentUnderTest, "hovered", false)

            const closeButton = findChild(componentUnderTest, "bannerCard_closeButton")
            verify(!!closeButton, "Object exists")
            compare(closeButton.visible, false)

            const touch = touchEvent(componentUnderTest)
            touch.press(0, componentUnderTest, 50, 35).commit()
            touch.release(0, componentUnderTest, 50, 35).commit()

            tryCompare(clickedSpy, "count", 1)
            compare(closeButton.visible, false)
        }

        function test_touchLongPressAndClose() {
            mouseMove(root, root.width - 1, root.height - 1)
            tryCompare(componentUnderTest, "hovered", false)

            const closeButton = findChild(componentUnderTest, "bannerCard_closeButton")
            verify(!!closeButton, "Object exists")
            compare(closeButton.visible, false)

            const touch = touchEvent(componentUnderTest)
            touch.press(0, componentUnderTest, 50, 35).commit()
            componentUnderTest.update()

            tryCompare(closeButton, "visible", true)
            touch.release(0, componentUnderTest, 50, 35).commit()

            compare(clickedSpy.count, 0)
            compare(closeButton.visible, true)

            // Tapping the revealed close button on touch emits close(), not clicked()
            const touchClose = touchEvent(closeButton)
            touchClose.press(0, closeButton, closeButton.width / 2, closeButton.height / 2).commit()
            touchClose.release(0, closeButton, closeButton.width / 2, closeButton.height / 2).commit()

            tryCompare(closeSpy, "count", 1)
            tryCompare(closeButton, "visible", false)
            compare(clickedSpy.count, 0)
        }

        function test_touchLongPressWithFingerDrift() {
            mouseMove(root, root.width - 1, root.height - 1)
            tryCompare(componentUnderTest, "hovered", false)

            const closeButton = findChild(componentUnderTest, "bannerCard_closeButton")
            verify(!!closeButton, "Object exists")

            const drift = Qt.styleHints.startDragDistance + 8

            const touch = touchEvent(componentUnderTest)
            touch.press(0, componentUnderTest, 50, 35).commit()
            // Drift past startDragDistance while staying well inside the card
            touch.move(0, componentUnderTest, 50 + drift, 35).commit()
            componentUnderTest.update()

            tryCompare(closeButton, "visible", true)
            touch.release(0, componentUnderTest, 50 + drift, 35).commit()

            compare(clickedSpy.count, 0)
            compare(closeButton.visible, true)

            componentUnderTest.reset()
            tryCompare(closeButton, "visible", false)

            // Real mouse hover after touch interaction must still reveal the close button
            mouseMove(componentUnderTest, componentUnderTest.width / 2, componentUnderTest.height / 2)
            tryCompare(closeButton, "visible", true)
        }
    }
}
