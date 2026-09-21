import QtQuick
import QtTest

import StatusQ.Core
import StatusQ.Popups

/**
 * Menu row metrics. The default is the app's long-standing row, and the
 * Design System numbers are opt-in — a menu that wants them sets them, so
 * changing one menu never moves the others.
 */
Item {
    id: root
    width: 400
    height: 400

    Component {
        id: menuComponent

        StatusMenu {
            StatusAction { icon.name: "share-ios"; text: "Share file" }
            StatusAction { icon.name: "link-2"; text: "Share URL" }
            StatusAction { icon.name: "folder"; text: "Show in folder" }
        }
    }

    TestCase {
        name: "StatusMenuMetrics"
        when: windowShown

        function openMenu(props) {
            const menu = createTemporaryObject(menuComponent, root, props)
            menu.popup(root, 10, 10)
            tryVerify(() => menu.opened, 5000)
            return menu
        }

        function test_defaultRow_isUnchanged() {
            const menu = openMenu({})
            const first = menu.itemAt(0)

            compare(first.icon.width, 18, "icon size")
            compare(first.spacing, 4, "icon to text")
            compare(first.backgroundRadius, 0, "no rounded highlight")
            compare(menu.itemAt(1).y - first.y, first.height, "rows sit flush")
            verify(first.height > 40, "the roomy row: " + first.height)

            menu.close()
        }

        // The Design System context menu: 30 high, 20px icon 8 from the text,
        // rows 8 apart, rounded where they highlight.
        function test_designSystemRow_isOptIn() {
            const menu = openMenu({
                itemIconSize: 20,
                itemTextSpacing: 8,
                itemVerticalPadding: 5,
                itemMinimumHeight: 30,
                itemBackgroundRadius: 10,
                itemsSpacing: 8
            })
            const first = menu.itemAt(0)

            compare(first.icon.width, 20, "icon size")
            compare(first.spacing, 8, "icon to text")
            compare(first.height, 30, "row height")
            compare(first.backgroundRadius, 10, "rounded highlight")
            compare(menu.itemAt(1).y - first.y, 38, "row pitch: 30 high, 8 apart")

            menu.close()
        }
    }
}
