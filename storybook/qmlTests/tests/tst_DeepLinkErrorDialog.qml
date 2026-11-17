import QtQuick
import QtQuick.Window
import QtTest

import AppLayouts.Chat.popups

Item {
    id: root
    width: 1000
    height: 700

    Component {
        id: dialogComponent
        DeepLinkErrorDialog {
            enter: Transition {}
            exit: Transition {}
        }
    }

    TestCase {
        name: "DeepLinkErrorDialog"
        when: windowShown

        function test_layoutAndDismissal_data() {
            return [
                {tag: "desktop-unavailable", mobile: false, noAccess: false},
                {tag: "desktop-no-access", mobile: false, noAccess: true},
                {tag: "mobile-unavailable", mobile: true, noAccess: false},
                {tag: "mobile-no-access", mobile: true, noAccess: true}
            ]
        }

        function test_layoutAndDismissal(row) {
            const window = root.Window.window
            window.width = row.mobile ? 414 : 1000
            window.height = row.mobile ? 800 : 700
            compare(window.width, row.mobile ? 414 : 1000)
            const dialog = createTemporaryObject(dialogComponent, root, {noAccess: row.noAccess})
            verify(dialog)
            dialog.open()
            compare(dialog.opened, true)
            if (row.mobile) {
                compare(dialog.width, window.width)
                compare(dialog.y + dialog.height, window.height)
            } else {
                compare(dialog.x, (window.width - dialog.width) / 2)
            }
            compare(dialog.title, row.noAccess ? "No access" : "Content unavailable")
            compare(findChild(dialog, "deepLinkErrorDescription").text, row.noAccess
                ? "You don't have permission to open this link. Get access to view it."
                : "The content couldn't be retrieved or may have been deleted.")
            verify(dialog.width <= window.width)
            verify(dialog.height <= window.height)
            const button = findChild(dialog, "deepLinkErrorDismissButton")
            verify(button)
            compare(button.text, "Got it")
            button.clicked()
            compare(dialog.visible, false)
        }

        function cleanupTestCase() {
            root.Window.window.width = 1000
            root.Window.window.height = 700
        }
    }
}
