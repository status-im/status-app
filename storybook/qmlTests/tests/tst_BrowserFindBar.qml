import QtQuick
import QtTest

import AppLayouts.Browser.panels

import "helpers/BrowserToolbarTestUtils.js" as BrowserToolbarTestUtils

Item {
    id: root

    width: 480
    height: 64

    Component {
        id: findBarComponent

        FindBar {
            width: 460
            height: 48
        }
    }

    TestCase {
        name: "BrowserFindBar"
        when: windowShown

        function test_visibleFocusTriggersFindNext() {
            const bar = createTemporaryObject(findBarComponent, root, { visible: false })
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = bar
            spy.signalName = "findNext"
            bar.text = "status"
            bar.visible = true
            compare(spy.count, 1)
        }

        function test_findNextAndPreviousButtons() {
            const bar = createTemporaryObject(findBarComponent, root, {
                numberOfMatches: 2,
                activeMatch: 1,
                visible: true
            })
            bar.text = "hello"
            const nextSpy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            nextSpy.target = bar
            nextSpy.signalName = "findNext"
            const prevSpy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            prevSpy.target = bar
            prevSpy.signalName = "findPrevious"
            const nextBtn = BrowserToolbarTestUtils.flatButtonByIcon(bar, "chevron-down")
            const prevBtn = BrowserToolbarTestUtils.flatButtonByIcon(bar, "chevron-up")
            verify(!!nextBtn && !!prevBtn)
            mouseClick(nextBtn, nextBtn.width / 2, nextBtn.height / 2)
            mouseClick(prevBtn, prevBtn.width / 2, prevBtn.height / 2)
            compare(nextSpy.count, 1)
            compare(prevSpy.count, 1)
        }

        function test_closeHidesBar() {
            const bar = createTemporaryObject(findBarComponent, root, { visible: true })
            const closeBtn = BrowserToolbarTestUtils.flatButtonByIcon(bar, "close")
            verify(!!closeBtn)
            mouseClick(closeBtn, closeBtn.width / 2, closeBtn.height / 2)
            verify(!bar.visible)
        }

        function test_resetClearsMatchesAndKeepsQuery() {
            const bar = createTemporaryObject(findBarComponent, root, {
                visible: true,
                numberOfMatches: 3,
                activeMatch: 2,
                text: "needle"
            })
            bar.reset()
            compare(bar.numberOfMatches, 0)
            compare(bar.activeMatch, 0)
            verify(!bar.visible)
            compare(bar.text, "needle")
        }
    }
}
