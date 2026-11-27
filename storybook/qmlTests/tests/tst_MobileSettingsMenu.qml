import QtQuick
import QtTest

import AppLayouts.Browser.popups

Item {
    id: root

    width: 400
    height: 800

    Component {
        id: menuComponent

        MobileSettingsMenu {
            incognitoMode: false
            supportsIncognito: false
            supportsZoom: false
            zoomFactor: 1
            supportsFind: false
        }
    }

    TestCase {
        name: "MobileSettingsMenu"
        when: windowShown

        function test_savingAFileIsOfferedOnlyForAnOpenedFile() {
            const menu = createTemporaryObject(menuComponent, root)
            menu.open()
            tryCompare(menu, "opened", true)
            const item = findChild(menu.contentItem, "saveFileItem")
            verify(!!item)
            verify(!item.visible)

            menu.canSaveFile = true
            verify(item.visible)
            tryVerify(() => item.height > 0)
            waitForRendering(item)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = menu
            spy.signalName = "saveFileRequested"
            mouseClick(item)
            compare(spy.count, 1)
            tryCompare(menu, "opened", false)
        }
    }
}
