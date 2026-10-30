import QtQuick
import QtQuick.Controls
import QtTest

import AppLayouts.Browser.panels

import utils

import "helpers/BrowserToolbarTestUtils.js" as BrowserToolbarTestUtils

/**
 * Desktop browser toolbar (screenshot row under tabs): navigation, home, incognito,
 * address bar, bookmark, dApps, wallet, tabs overview, overflow menu.
 */
Item {
    id: root

    width: 1100
    height: 80

    ListModel {
        id: historyModel
        ListElement { title: "Back"; offset: -1; icon: "" }
        ListElement { title: "Here"; offset: 0; icon: "" }
    }

    ListModel {
        id: dappsModel
        ListElement {
            name: "Connected dApp"
            url: "https://dapp.test"
            iconUrl: ""
            connectorBadge: ""
        }
    }

    Component {
        id: toolbarComponent

        BrowserLandscapeToolbar {
            isMobile: false
            url: "https://status.app/"
            openTabsCount: 1
            currentTabIncognito: false
            currentTabIsBookmark: false
            currentTabLoading: false
            canGoBack: true
            canGoForward: true
            browserDappsModel: dappsModel
            historyModel: historyModel
        }
    }

    TestCase {
        name: "BrowserLandscapeToolbar"
        when: windowShown

        function makeToolbar(props) {
            return createTemporaryObject(toolbarComponent, root, props || {})
        }

        function clickIcon(toolbar, iconName) {
            const btn = BrowserToolbarTestUtils.headerButtonByIcon(toolbar, iconName)
            verify(!!btn, "missing toolbar icon: " + iconName)
            mouseClick(btn, btn.width / 2, btn.height / 2)
        }

        function test_back_requestsGoBack() {
            const toolbar = makeToolbar()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "requestGoBack"
            clickIcon(toolbar, "arrow-previous")
            compare(spy.count, 1)
        }

        function test_forward_requestsGoForward() {
            const toolbar = makeToolbar()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "requestGoForward"
            clickIcon(toolbar, "arrow-next")
            compare(spy.count, 1)
        }

        function test_reload_requestsReloadPage() {
            const toolbar = makeToolbar()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "requestReloadPage"
            clickIcon(toolbar, "refresh")
            compare(spy.count, 1)
        }

        function test_stop_requestsStopWhenLoading() {
            const toolbar = makeToolbar({ currentTabLoading: true })
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "requestStopLoadingPage"
            clickIcon(toolbar, "close-circle")
            compare(spy.count, 1)
        }

        function test_home_opensDefaultHomepage() {
            const toolbar = makeToolbar()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "requestLaunchInBrowser"
            clickIcon(toolbar, "home")
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], Constants.browserDefaultHomepage)
        }

        function test_incognitoToggle_emitsGoIncognito() {
            const toolbar = makeToolbar()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "goIncognito"
            clickIcon(toolbar, "privacy")
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], true)
        }

        function test_addressBarSubmit_passesEditedUrl() {
            const toolbar = makeToolbar()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "requestLaunchInBrowser"
            const addressBar = BrowserToolbarTestUtils.addressFieldInToolbar(toolbar)
            verify(!!addressBar, "address field in toolbar")
            addressBar.forceActiveFocus()
            addressBar.text = "https://example.com"
            keyClick(Qt.Key_Return)
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], "https://example.com")
        }

        function test_bookmark_addWhenNotBookmarked() {
            const toolbar = makeToolbar()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "addBookmarkRequested"
            clickIcon(toolbar, "bookmark")
            compare(spy.count, 1)
        }

        function test_bookmark_removeWhenBookmarked() {
            const toolbar = makeToolbar({ currentTabIsBookmark: true })
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "removeBookmarkRequested"
            clickIcon(toolbar, "bookmark-added")
            compare(spy.count, 1)
        }

        function test_wallet_opensWalletMenu() {
            const toolbar = makeToolbar()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "requestWalletMenu"
            clickIcon(toolbar, "homepage/wallet")
            compare(spy.count, 1)
        }

        function test_openTabsView_requestsOverview() {
            const toolbar = makeToolbar()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "requestAllOpenTabsView"
            const btn = findChild(toolbar, "openTabsViewButton")
            verify(!!btn)
            mouseClick(btn, btn.width / 2, btn.height / 2)
            compare(spy.count, 1)
        }

        function test_overflowMenu_requestsSettingsMenu() {
            const toolbar = makeToolbar()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = toolbar
            spy.signalName = "openSettingMenu"
            clickIcon(toolbar, "more")
            compare(spy.count, 1)
        }
    }
}
