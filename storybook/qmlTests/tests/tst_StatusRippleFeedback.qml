import QtQuick
import QtTest

import StatusQ.Core.Theme
import StatusQ.Components
import StatusQ.Controls
import StatusQ.Popups

Item {
    id: root
    width: 600
    height: 400

    Component {
        id: comboBoxComponent

        StatusComboBox {
            width: 240
            model: ["One", "Two"]
        }
    }

    Component {
        id: itemDelegateComponent

        StatusItemDelegate {
            property int clickCount: 0

            width: 240
            height: 40
            text: "One"
            onClicked: clickCount++
        }
    }

    Component {
        id: listItemComponent

        StatusListItem {
            property int clickCount: 0

            width: 240
            title: "One"
            onClicked: clickCount++
        }
    }

    Component {
        id: menuItemComponent

        StatusMenuItem {
            property int clickCount: 0

            width: 240
            height: 40
            text: "One"
            onClicked: clickCount++
        }
    }

    property Item controlUnderTest: null

    TestCase {
        name: "StatusRippleFeedback"
        when: windowShown

        function cleanup() {
            if (!!controlUnderTest)
                controlUnderTest.destroy()
        }

        function verifyRippleFeedback(item, rippleObjectName, followsPointer, expectClick) {
            const ripple = findChild(item, rippleObjectName)
            verify(!!ripple)
            verify(ripple.enabled)
            verify(!ripple.visible)

            const pressX = item.width / 4
            const pressY = item.height / 2
            const clickCount = expectClick ? item.clickCount : 0

            mousePress(item, pressX, pressY)
            tryVerify(() => ripple.visible)
            verify(ripple.pressed)
            compare(ripple.pressX, followsPointer ? pressX : item.width / 2)
            compare(ripple.pressY, pressY)

            mouseRelease(item, pressX, pressY)
            tryCompare(ripple, "visible", false)
            verify(!ripple.pressed)
            if (expectClick)
                compare(item.clickCount, clickCount + 1)
        }

        function test_comboBoxRipple() {
            controlUnderTest = createTemporaryObject(comboBoxComponent, root)
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest.control, "statusComboBoxRipple", false, false)
            compare(controlUnderTest.control.scale, 1)
        }

        function test_itemDelegateRipple() {
            controlUnderTest = createTemporaryObject(itemDelegateComponent, root)
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest, "statusItemDelegateRipple", true, true)
            compare(controlUnderTest.scale, 1)
        }

        function test_highlightedItemDelegateDefaultColors() {
            controlUnderTest = createTemporaryObject(itemDelegateComponent, root, { highlighted: true })
            verify(!!controlUnderTest)

            const textItem = controlUnderTest.contentItem.children[1]
            const ripple = findChild(controlUnderTest, "statusItemDelegateRipple")
            verify(!!textItem)
            verify(!!ripple)
            compare(textItem.color, Theme.palette.directColor1)
            compare(ripple.color, Theme.palette.directColor1)
        }

        function test_highlightedItemDelegatePrimaryColors() {
            controlUnderTest = createTemporaryObject(itemDelegateComponent, root, {
                highlighted: true,
                highlightColor: Theme.palette.primaryColor1
            })
            verify(!!controlUnderTest)

            const textItem = controlUnderTest.contentItem.children[1]
            const ripple = findChild(controlUnderTest, "statusItemDelegateRipple")
            verify(!!textItem)
            verify(!!ripple)
            compare(textItem.color, StatusColors.white)
            compare(ripple.color, StatusColors.white)
        }

        function test_listItemRipple() {
            controlUnderTest = createTemporaryObject(listItemComponent, root)
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest, "statusListItemRipple", true, true)
            compare(controlUnderTest.scale, 1)
        }

        function test_menuItemRipple() {
            controlUnderTest = createTemporaryObject(menuItemComponent, root)
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest, "statusMenuItemRipple", true, true)
            compare(controlUnderTest.scale, 1)
        }
    }
}
