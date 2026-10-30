import QtQuick
import QtTest

import AppLayouts.Browser

import "helpers/BrowserToolbarTestUtils.js" as BrowserToolbarTestUtils

Item {
    id: root

    width: 480
    height: 360

    Component {
        id: wallComponent

        BrowserPrivacyWall {}
    }

    TestCase {
        name: "BrowserPrivacyWall"
        when: windowShown

        function test_enableThirdPartyServicesRequested() {
            const wall = createTemporaryObject(wallComponent, root)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = wall
            spy.signalName = "openThirdpartyServicesInfoPopupRequested"
            const carousel = wall.centerPanel
            verify(!!carousel)
            const enableBtn = BrowserToolbarTestUtils.itemByText(carousel, qsTr("Enable third-party services"))
            verify(!!enableBtn)
            mouseClick(enableBtn, enableBtn.width / 2, enableBtn.height / 2)
            compare(spy.count, 1)
        }

        function test_discussLinkRequested() {
            const wall = createTemporaryObject(wallComponent, root)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = wall
            spy.signalName = "openDiscussPageRequested"
            const carousel = wall.centerPanel
            verify(!!carousel)
            let richText = null
            BrowserToolbarTestUtils.walkItemTree(carousel, function(o) {
                if (richText)
                    return
                if (o.linkActivated !== undefined && o.textFormat === Text.RichText)
                    richText = o
            })
            verify(!!richText)
            richText.linkActivated("#")
            compare(spy.count, 1)
        }
    }
}
