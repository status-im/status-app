import QtQuick
import QtTest

import AppLayouts.Browser.views

import "helpers/BrowserToolbarTestUtils.js" as BrowserToolbarTestUtils

Item {
    id: root

    width: 420
    height: 320

    Component {
        id: pageComponent

        CrashedWebPage {
            width: 400
            height: 300
        }
    }

    TestCase {
        name: "CrashedWebPage"
        when: windowShown

        function test_reloadRequested() {
            const page = createTemporaryObject(pageComponent, root)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = page
            spy.signalName = "reloadRequested"
            const reloadBtn = BrowserToolbarTestUtils.itemByText(page, qsTr("Reload"))
            verify(!!reloadBtn)
            mouseClick(reloadBtn, reloadBtn.width / 2, reloadBtn.height / 2)
            compare(spy.count, 1)
        }
    }
}
