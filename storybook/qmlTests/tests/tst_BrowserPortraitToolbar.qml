import QtQuick
import QtTest

import AppLayouts.Browser.panels

import "helpers/BrowserToolbarTestUtils.js" as BrowserToolbarTestUtils

/**
 * Mobile browser footer toolbar: tabs, bookmark, back, search, forward, incognito, menu.
 */
Item {
    id: root

    width: 420
    height: 80

    ListModel {
        id: historyModel
        ListElement { title: "Prev"; offset: -1; icon: "" }
    }

    ListModel {
        id: dappsModel
        ListElement { name: "d"; url: "https://d.app"; iconUrl: ""; connectorBadge: "" }
    }

    Component {
        id: toolbarComponent

        BrowserPortraitToolbar {
            isMobile: true
            openTabsCount: 3
            currentTabIncognito: false
            currentTabIsBookmark: false
            currentTabLoading: false
            canGoBack: true
            canGoForward: false
            browserDappsModel: dappsModel
            historyModel: historyModel
        }
    }

    TestCase {
        name: "BrowserPortraitToolbar"
        when: windowShown

        function clickIcon(toolbar, iconName) {
            const btn = BrowserToolbarTestUtils.headerButtonByIcon(toolbar, iconName)
            verify(!!btn, "missing icon " + iconName)
            mouseClick(btn, btn.width / 2, btn.height / 2)
        }

        function test_openTabsView() {
            const toolbar = createTemporaryObject(toolbarComponent, root)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "requestAllOpenTabsView"
            clickIcon(toolbar, "open-tabs")
            compare(spy.count, 1)
        }

        function test_search() {
            const toolbar = createTemporaryObject(toolbarComponent, root)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "requestSearch"
            clickIcon(toolbar, "search")
            compare(spy.count, 1)
        }

        function test_backAndForward() {
            const toolbar = createTemporaryObject(toolbarComponent, root, { canGoForward: true })
            const backSpy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            backSpy.target = toolbar
            backSpy.signalName = "requestGoBack"
            clickIcon(toolbar, "arrow-previous")
            compare(backSpy.count, 1)

            const fwdSpy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            fwdSpy.target = toolbar
            fwdSpy.signalName = "requestGoForward"
            clickIcon(toolbar, "arrow-next")
            compare(fwdSpy.count, 1)
        }

        function test_overflowMenu() {
            const toolbar = createTemporaryObject(toolbarComponent, root)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "openSettingMenu"
            clickIcon(toolbar, "more")
            compare(spy.count, 1)
        }
    }
}
