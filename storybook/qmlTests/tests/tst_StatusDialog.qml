import QtQuick
import QtQuick.Controls
import QtTest

import StatusQ.Core
import StatusQ.Core.Theme
import StatusQ.Popups.Dialog

import utils

Item {
    id: root
    width: d.desktopWindowWidth
    height: d.desktopWindowHeight

    Component {
        id: componentUnderTest
        StatusDialog {
            width: 400
            title: "Test dialog"
            standardButtons: Dialog.Ok
            contentItem: StatusBaseText {
                text: "Nothing to see here"
            }
        }
    }

    QtObject {
        id: d
        readonly property int desktopWindowWidth: ThemeUtils.portraitBreakpoint.width + 100
        readonly property int desktopWindowHeight: ThemeUtils.portraitBreakpoint.height + 100
        readonly property int mobileWindowWidth: mobileWindowHeight / 2
        readonly property int mobileWindowHeight: ThemeUtils.portraitBreakpoint.height - 100
    }

    property StatusDialog controlUnderTest: null

    TestCase {
        name: "StatusDialog"
        when: windowShown

        function init() {
            controlUnderTest = createTemporaryObject(componentUnderTest, root)
        }

        function cleanup() {
            root.width = d.desktopWindowWidth
            root.height = d.desktopWindowHeight
        }

        function test_centered_on_desktop() {
            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)

            tryCompare(controlUnderTest, "width", 400) // popup width should stay the same
            verify(controlUnderTest.height > 0)

            tryVerify(() => controlUnderTest.x > 0) // popup not stuck in topleft corner
            tryVerify(() => controlUnderTest.y > 0)

            compare(controlUnderTest.bottomSheet, false) // not bottom sheet on desktop
        }

        function test_popupType_is_item() {
            compare(controlUnderTest.popupType, Popup.Item)
        }

        function test_nested_dialog_stays_item_and_centered() {
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)

            const nested = createTemporaryObject(componentUnderTest, root)
            verify(!!nested)
            nested.open()
            tryCompare(nested, "opened", true)

            compare(nested.popupType, Popup.Item)
            tryVerify(() => nested.x > 0)
            tryVerify(() => nested.y > 0)
            compare(nested.parent, nested.Overlay.overlay)
        }

        function test_bottomSheet_on_mobile() {
            root.width = d.mobileWindowWidth
            root.height = d.mobileWindowHeight

            verify(!!controlUnderTest)
            controlUnderTest.open()
            tryCompare(controlUnderTest, "opened", true)

            tryCompare(controlUnderTest, "width", root.width) // popup width should match the window width
            verify(controlUnderTest.height > 0)

            compare(controlUnderTest.bottomSheet, true) // bottom sheet on mobile
        }
    }
}
