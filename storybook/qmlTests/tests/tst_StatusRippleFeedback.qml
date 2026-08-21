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

    Component {
        id: roundButtonComponent

        StatusRoundButton {
            property int clickCount: 0

            icon.name: "close"
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

        // Asserts both halves of the deferral: nothing is built before the
        // first press, and the ripple that press builds reacts to that same
        // press - the press signal must reach it after it exists.
        function verifyRippleFeedback(item, rippleObjectName, followsPointer, expectClick) {
            verify(!findChild(item, rippleObjectName),
                   "the ripple must not be built before the first press")

            const pressX = item.width / 4
            const pressY = item.height / 2
            const clickCount = expectClick ? item.clickCount : 0

            mousePress(item, pressX, pressY)

            const ripple = findChild(item, rippleObjectName)
            verify(!!ripple, "the press must build the ripple")
            verify(ripple.enabled)
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

        // The colour bindings live on the deferred item, so a press is what
        // makes them observable.
        function pressedRipple(item, rippleObjectName) {
            mousePress(item, item.width / 4, item.height / 2)
            mouseRelease(item, item.width / 4, item.height / 2)
            return findChild(item, rippleObjectName)
        }

        function test_comboBoxRipple() {
            controlUnderTest = createTemporaryObject(comboBoxComponent, root)
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest.control, "statusComboBoxRipple", true, false)
            compare(controlUnderTest.control.scale, 1)

            controlUnderTest.destroy()
            controlUnderTest = createTemporaryObject(comboBoxComponent, root, {
                rippleOrigin: StatusRipple.RippleOrigin.Center
            })
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest.control, "statusComboBoxRipple", false, false)
        }

        function test_itemDelegateRipple() {
            controlUnderTest = createTemporaryObject(itemDelegateComponent, root)
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest, "statusItemDelegateRipple", true, true)
            compare(controlUnderTest.scale, 1)

            controlUnderTest.destroy()
            controlUnderTest = createTemporaryObject(itemDelegateComponent, root, {
                rippleOrigin: StatusRipple.RippleOrigin.Center
            })
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest, "statusItemDelegateRipple", false, true)
        }

        function test_highlightedItemDelegateDefaultColors() {
            controlUnderTest = createTemporaryObject(itemDelegateComponent, root, { highlighted: true })
            verify(!!controlUnderTest)

            const textItem = controlUnderTest.contentItem.children[1]
            const ripple = pressedRipple(controlUnderTest, "statusItemDelegateRipple")
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
            const ripple = pressedRipple(controlUnderTest, "statusItemDelegateRipple")
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

            controlUnderTest.destroy()
            controlUnderTest = createTemporaryObject(listItemComponent, root, {
                rippleOrigin: StatusRipple.RippleOrigin.Center
            })
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest, "statusListItemRipple", false, true)
        }

        function test_menuItemRipple() {
            controlUnderTest = createTemporaryObject(menuItemComponent, root)
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest, "statusMenuItemRipple", true, true)
            compare(controlUnderTest.scale, 1)

            controlUnderTest.destroy()
            controlUnderTest = createTemporaryObject(menuItemComponent, root, {
                rippleOrigin: StatusRipple.RippleOrigin.Center
            })
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest, "statusMenuItemRipple", false, true)
        }

        function test_disabledControlsBuildNoRipple_data() {
            return [
                { tag: "comboBox", component: comboBoxComponent,
                  rippleObjectName: "statusComboBoxRipple" },
                { tag: "itemDelegate", component: itemDelegateComponent,
                  rippleObjectName: "statusItemDelegateRipple" },
                { tag: "listItem", component: listItemComponent,
                  rippleObjectName: "statusListItemRipple" },
                { tag: "menuItem", component: menuItemComponent,
                  rippleObjectName: "statusMenuItemRipple" },
                { tag: "roundButton", component: roundButtonComponent,
                  rippleObjectName: "buttonRipple" }
            ]
        }

        function test_disabledControlsBuildNoRipple(data) {
            controlUnderTest = createTemporaryObject(data.component, root, { enabled: false })
            verify(!!controlUnderTest)

            mousePress(controlUnderTest, controlUnderTest.width / 4, controlUnderTest.height / 2)
            mouseRelease(controlUnderTest, controlUnderTest.width / 4, controlUnderTest.height / 2)

            verify(!findChild(controlUnderTest, data.rippleObjectName),
                   "a control that cannot react must not build a ripple")
        }

        function test_nonInteractiveComboBoxBuildsNoRipple() {
            controlUnderTest = createTemporaryObject(comboBoxComponent, root, { interactive: false })
            verify(!!controlUnderTest)

            const comboBox = controlUnderTest.control
            mousePress(comboBox, comboBox.width / 4, comboBox.height / 2)
            mouseRelease(comboBox, comboBox.width / 4, comboBox.height / 2)

            verify(!findChild(controlUnderTest, "statusComboBoxRipple"))
        }

        function test_roundButtonRipple() {
            controlUnderTest = createTemporaryObject(roundButtonComponent, root)
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest, "buttonRipple", true, true)

            controlUnderTest.destroy()
            controlUnderTest = createTemporaryObject(roundButtonComponent, root, {
                rippleOrigin: StatusRipple.RippleOrigin.Center
            })
            verify(!!controlUnderTest)

            verifyRippleFeedback(controlUnderTest, "buttonRipple", false, true)

            const ripple = findChild(controlUnderTest, "buttonRipple")
            verify(!!ripple)
            controlUnderTest.rippleEnabled = false
            verify(!ripple.enabled)
            mousePress(controlUnderTest, controlUnderTest.width / 2, controlUnderTest.height / 2)
            verify(!ripple.visible)
            mouseRelease(controlUnderTest, controlUnderTest.width / 2, controlUnderTest.height / 2)
        }
    }
}
