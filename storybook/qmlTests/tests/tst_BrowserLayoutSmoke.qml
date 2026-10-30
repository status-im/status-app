import QtQuick
import QtTest

import AppLayouts.Browser.popups
import AppLayouts.Browser.stores as BrowserStores

import "helpers/BrowserToolbarTestUtils.js" as BrowserToolbarTestUtils

Item {
    id: root

    width: 960
    height: 500

    BrowserStores.BookmarksStore {
        id: overviewBookmarksStore
    }

    Component {
        id: overviewComponent

        TabsBookmarksOverviewModal {
            tabsModel: [
                { title: "Status App", url: "https://status.app/" },
                { title: "Hub", url: "https://hub.status.network/" }
            ]
            currentTabIndex: 0
            bookmarksModel: overviewBookmarksStore.bookmarksModel
            downloadsModel: []
            getTitleFn: (index) => tabsModel[index] ? tabsModel[index].title : ""
            getFaviconFn: () => ""
            getWebViewScreenshot: () => ""
        }
    }

    TestCase {
        name: "BrowserLayoutSmoke"
        when: windowShown

        function test_overview_openTabsTitle() {
            const modal = createTemporaryObject(overviewComponent, root)
            modal.open()
            tryCompare(modal, "opened", true)
            compare(modal.title, qsTr("Open tabs"))
        }

        function test_overview_bookmarksTab() {
            const modal = createTemporaryObject(overviewComponent, root)
            modal.open()
            tryCompare(modal, "opened", true)
            const tab = findChild(modal, "overviewBookmarksTab")
            verify(!!tab)
            mouseClick(tab, tab.width / 2, tab.height / 2)
            compare(modal.title, qsTr("Bookmarks"))
        }

        function test_overview_downloadsTab() {
            const modal = createTemporaryObject(overviewComponent, root)
            modal.open()
            tryCompare(modal, "opened", true)
            const tab = findChild(modal, "overviewDownloadsTab")
            verify(!!tab)
            mouseClick(tab, tab.width / 2, tab.height / 2)
            compare(modal.title, qsTr("Downloads"))
        }

        function test_overview_addTabRequested() {
            const modal = createTemporaryObject(overviewComponent, root)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = modal
            spy.signalName = "addTabRequested"
            modal.open()
            tryCompare(modal, "opened", true)
            const addBtn = BrowserToolbarTestUtils.flatButtonByIcon(modal, "add")
            verify(!!addBtn, "overview add tab button")
            mouseClick(addBtn, addBtn.width / 2, addBtn.height / 2)
            compare(spy.count, 1)
        }
    }
}
