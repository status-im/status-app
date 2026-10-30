import QtQuick
import QtTest

import StatusQ.Core.Theme

import AppLayouts.Browser.controls

import "helpers/BrowserToolbarTestUtils.js" as BrowserToolbarTestUtils

Item {
    id: root

    width: 640
    height: 80

    Component {
        id: fieldComponent

        BrowserAddressField {
            url: "https://status.app/"
            incognitoMode: false
            bgColor: Theme.palette.baseColor2
        }
    }

    TestCase {
        name: "BrowserAddressField"
        when: windowShown

        function test_displaysBoundUrl() {
            const field = createTemporaryObject(fieldComponent, root)
            compare(field.text, "https://status.app/")
        }

        function test_editedTextRevertsOnBlurWhenUrlNonEmpty() {
            const field = createTemporaryObject(fieldComponent, root)
            field.forceActiveFocus()
            field.text = "https://example.com"
            field.focus = false
            waitForRendering(field)
            compare(field.text, "https://status.app/")
        }

        function test_acceptedAfterEditingText() {
            const field = createTemporaryObject(fieldComponent, root)
            const spy = createTemporaryQmlObject("import QtTest; SignalSpy {}", root)
            spy.target = field
            spy.signalName = "accepted"
            field.forceActiveFocus()
            field.text = "example.com"
            keyClick(Qt.Key_Return)
            compare(spy.count, 1)
            compare(field.text, "example.com")
        }

        function test_clearButtonClearsTextWhileFocused() {
            const field = createTemporaryObject(fieldComponent, root)
            field.forceActiveFocus()
            verify(field.cursorVisible)
            let clearBtn = null
            BrowserToolbarTestUtils.walkItemTree(field, function(o) {
                if (clearBtn)
                    return
                if (o.toString().indexOf("StatusClearButton") >= 0)
                    clearBtn = o
            })
            verify(!!clearBtn)
            verify(clearBtn.visible)
            mouseClick(clearBtn, clearBtn.width / 2, clearBtn.height / 2)
            compare(field.text, "")
        }

        function test_incognitoUsesPrivacyTextColor() {
            const field = createTemporaryObject(fieldComponent, root, { incognitoMode: true })
            compare(field.color, Theme.palette.privacyColors.tertiary)
        }
    }
}
