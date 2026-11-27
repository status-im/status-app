import QtQuick
import QtTest

import AppLayouts.Browser.popups

import "helpers/BrowserToolbarTestUtils.js" as BrowserToolbarTestUtils

/**
 * Overflow menu (three dots): new tab, downloads, find, zoom, settings, clear data.
 */
Item {
    id: root

    width: 400
    height: 600

    Component {
        id: menuComponent

        BrowserSettingsMenu {
            incognitoMode: false
            zoomFactor: 1.25
            browserSettings: QtObject { property bool devToolsEnabled: false }
        }
    }

    TestCase {
        name: "BrowserSettingsMenu"
        when: windowShown

        function openMenu() {
            const menu = createTemporaryObject(menuComponent, root)
            menu.open()
            tryCompare(menu, "opened", true)
            return menu
        }

        function trigger(menu, label) {
            const entry = BrowserToolbarTestUtils.menuEntryByText(menu, label)
            verify(!!entry, "menu entry: " + label)
            if (entry.action && typeof entry.action.trigger === "function")
                entry.action.trigger()
            else if (typeof entry.trigger === "function")
                entry.trigger()
            else
                mouseClick(entry, entry.width / 2, entry.height / 2)
        }

        function test_copyFilePath_onlyForAnOpenedFile() {
            const menu = openMenu()
            const entry = BrowserToolbarTestUtils.menuEntryByText(menu, qsTr("Copy file path"))
            verify(!!entry)
            verify(!entry.visible)

            menu.canCopyFilePath = true
            verify(entry.visible)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = menu
            spy.signalName = "copyFilePath"
            trigger(menu, qsTr("Copy file path"))
            compare(spy.count, 1)
        }

        function test_newTab() {
            const menu = openMenu()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = menu
            spy.signalName = "addNewTab"
            trigger(menu, qsTr("New Tab"))
            compare(spy.count, 1)
        }

        function test_downloads() {
            const menu = openMenu()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = menu
            spy.signalName = "openDownloads"
            trigger(menu, qsTr("Downloads"))
            compare(spy.count, 1)
        }

        function test_findInPage() {
            const menu = openMenu()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = menu
            spy.signalName = "launchFindBar"
            trigger(menu, qsTr("Find in page"))
            compare(spy.count, 1)
        }

        function test_supportedFormats() {
            const menu = openMenu()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = menu
            spy.signalName = "openSupportedFormats"
            trigger(menu, qsTr("Supported formats"))
            compare(spy.count, 1)
        }

        function test_browserSettings() {
            const menu = openMenu()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = menu
            spy.signalName = "launchBrowserSettings"
            trigger(menu, qsTr("Settings"))
            compare(spy.count, 1)
        }

        function test_zoomOut() {
            const menu = openMenu()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = menu
            spy.signalName = "zoomOut"
            const zoomOutBtn = BrowserToolbarTestUtils.flatButtonByIcon(menu, "zoom-out")
            verify(!!zoomOutBtn)
            mouseClick(zoomOutBtn, zoomOutBtn.width / 2, zoomOutBtn.height / 2)
            compare(spy.count, 1)
        }

        function test_clearBrowsingData() {
            const menu = openMenu()
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = menu
            spy.signalName = "clearBrowsingData"
            trigger(menu, qsTr("Clear browsing data"))
            compare(spy.count, 1)
        }
    }
}
