import QtQuick
import QtTest

import AppLayouts.Browser.popups

import utils

import "helpers/BrowserToolbarTestUtils.js" as BrowserToolbarTestUtils

Item {
    id: root

    width: 600
    height: 400

    Component {
        id: modalComponent

        AddFavoriteModal {
            incognitoMode: false
            ogUrl: "https://status.app/"
            ogName: "Status"
        }
    }

    TestCase {
        name: "AddFavoriteModal"
        when: windowShown

        function test_addBookmark_emitsUrlAndName() {
            const modal = createTemporaryObject(modalComponent, root)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = modal
            spy.signalName = "addBookmarkRequested"
            modal.open()
            tryCompare(modal, "opened", true)
            const saveBtn = BrowserToolbarTestUtils.itemByText(modal, qsTr("Add"))
            verify(!!saveBtn, "Add bookmark button")
            mouseClick(saveBtn, saveBtn.width / 2, saveBtn.height / 2)
            // The modal drops the add-bookmark chip, emits the real bookmark,
            // then emits the chip again so it stays at the end of the bar.
            compare(spy.count, 2)
            compare(spy.signalArguments[0][0], "https://status.app/")
            compare(spy.signalArguments[0][1], "Status")
            compare(spy.signalArguments[1][0], Constants.newBookmark)
        }
    }
}
