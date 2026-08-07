import QtQuick
import QtTest

import AppLayouts.Browser.panels

/**
 * BrowserTabView: the tab strip doubles as the macOS titlebar, so three
 * mechanisms share the same 44px band — the tab bar ListView (flickable only
 * while the tabs overflow), a double-tap-to-open-a-new-tab TapHandler inside
 * it, and a DragHandler over the empty strip that starts the system window
 * move. These tests pin down that they do not cancel each other out.
 *
 * Double taps are driven with touch: QtQuickTest bumps the mouse timestamp by
 * 500ms after every release, which is past the 400ms double click interval, so
 * synthetic mouse clicks can never add up to a double tap.
 */
Item {
    id: root
    width: 900
    height: 120

    QtObject {
        id: sessionContextMock

        function displayTitle(webView, isStartPage) { return isStartPage ? "New tab" : "Tab" }
        function displayIcon(webView) { return "" }
    }

    Component {
        id: tabViewComponent

        BrowserTabView {
            width: 900
            height: 44
            currentTabIncognito: false
            isMobile: false
            savedSessionContext: sessionContextMock
            fnGetWebView: (index) => null
        }
    }

    TestCase {
        name: "BrowserTabView"
        when: windowShown

        function createView(tabCount) {
            const view = createTemporaryObject(tabViewComponent, root)
            verify(!!view)
            for (let i = 0; i < tabCount; ++i)
                view.createEmptyTab(true)
            waitForRendering(view)
            return view
        }

        function tabList(view) {
            const list = findChild(view, "tabBarListView")
            verify(!!list)
            return list
        }

        function dragArea(view) {
            const area = findChild(view, "tabStripDragArea")
            verify(!!area)
            return area
        }

        function newTabSpy(view) {
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = view
            spy.signalName = "openNewTabTriggered"
            return spy
        }

        function doubleTap(view, x, y) {
            const seq = touchEvent(view)
            seq.press(0, view, x, y).commit()
            seq.release(0, view, x, y).commit()
            seq.press(0, view, x, y).commit()
            seq.release(0, view, x, y).commit()
            wait(0)
        }

        function test_flickable_interactiveOnlyWhenOverflowing() {
            compare(tabList(createView(1)).interactive, false)
            compare(tabList(createView(12)).interactive, true)
        }

        // `interactive: false` must not stop the double tap from reaching the
        // TapHandler declared inside the very same ListView.
        function test_doubleTap_inEmptyStrip_opensNewTab() {
            const view = createView(1)
            const area = dragArea(view)
            verify(area.visible)
            compare(tabList(view).interactive, false)

            const spy = newTabSpy(view)
            doubleTap(view, area.x + area.width / 2, 22)
            compare(spy.count, 1)
        }

        // A tab takes the grab itself, in either overflow state — the empty
        // strip is the only surface the new-tab double tap ever reacted to.
        function test_doubleTap_onTab_selectsTabWithoutOpeningANewOne_data() {
            return [
                        {tag: "tabs fit", tabCount: 2},
                        {tag: "tabs overflow", tabCount: 12},
                    ]
        }

        function test_doubleTap_onTab_selectsTabWithoutOpeningANewOne(data) {
            const view = createView(data.tabCount)
            compare(view.currentIndex, data.tabCount - 1)

            const spy = newTabSpy(view)
            doubleTap(view, 40, 22)
            compare(view.currentIndex, 0, "the tap selects the first tab")
            compare(spy.count, 0)
        }

        // ListView.contentWidth already covers the footer, so offsetting the
        // drag area by it a second time left a dead band next to the + button
        // where dragging the window did nothing.
        function test_dragArea_startsRightAfterTheAddTabButton() {
            const view = createView(1)
            const list = tabList(view)
            const area = dragArea(view)
            verify(!!list.footerItem)
            compare(area.x, list.contentWidth, "no dead band between + and the drag strip")
            compare(area.x + area.width, view.width, "the strip reaches the window controls")
        }

        function test_dragArea_followsTheTabs() {
            const view = createView(1)
            const list = tabList(view)
            const area = dragArea(view)
            const singleTabX = area.x

            view.createEmptyTab(true)
            waitForRendering(view)
            compare(area.x, list.contentWidth)
            verify(area.x > singleTabX)
        }

        function test_dragArea_hidden_whenOverflowing() {
            compare(dragArea(createView(12)).visible, false)
        }
    }
}
