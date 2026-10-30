import QtQuick
import QtTest

import AppLayouts.Browser.panels

import utils

Item {
    id: root

    width: 600
    height: 56

    Component {
        id: barComponent

        FavoritesBar {
            width: 580
            height: 44
        }
    }

    TestCase {
        name: "BrowserFavoritesBar"
        when: windowShown

        function makeBookmarkModel() {
            const model = createTemporaryQmlObject("import QtQuick; ListModel {}", root)
            model.append({
                name: "Status",
                url: "https://status.app/",
                imageUrl: ""
            })
            model.append({
                name: "Add bookmark",
                url: Constants.newBookmark,
                imageUrl: ""
            })
            return model
        }

        function makeBar() {
            const bar = createTemporaryObject(barComponent, root, {
                bookmarkModel: makeBookmarkModel()
            })
            waitForRendering(bar)
            return bar
        }

        function favoritesList(bar) {
            const list = findChild(bar, "browserFavoritesListView")
            verify(!!list, "browserFavoritesListView")
            return list
        }

        function test_favoriteClick_navigatesToUrl() {
            const bar = makeBar()
            const list = favoritesList(bar)
            tryVerify(function () { return !!list.itemAtIndex(0) })
            const btn = list.itemAtIndex(0)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = bar
            spy.signalName = "setAsCurrentWebUrl"
            mouseClick(btn, btn.width / 2, btn.height / 2)
            compare(spy.count, 1)
            compare(spy.signalArguments[0][0], "https://status.app/")
        }

        function test_addBookmarkChip_requestsAdd() {
            const bar = makeBar()
            const list = favoritesList(bar)
            tryVerify(function () { return !!list.itemAtIndex(1) })
            const btn = list.itemAtIndex(1)
            verify(btn.isAddBookmarkButton)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = bar
            spy.signalName = "addBookmarkRequested"
            mouseClick(btn, btn.width / 2, btn.height / 2)
            compare(spy.count, 1)
        }
    }
}
