import QtQuick
import QtTest

import shared.controls
import utils

// The status menu is built when the button is clicked and destroyed when it closes.
Item {
    id: root

    width: 600
    height: 600

    Component {
        id: buttonComponent

        ProfileButton {
            x: 20
            y: 500
            name: "Alice"
            usesDefaultName: ""
            pubKey: "0x04abc"
            compressedPubKey: "zQ3abc"
            iconSource: ""
            colorId: 1
            currentUserStatus: Constants.currentUserStatus.automatic
            getEmojiHashFn: pubKey => []
            getLinkToProfileFn: pubKey => "https://status.app/u/" + pubKey
        }
    }

    Component {
        id: signalSpy
        SignalSpy {}
    }

    TestCase {
        name: "ProfileButton"
        when: windowShown

        property var menu: null  // a var drops to null when its object is destroyed

        function menuOf(button) {
            return findChild(button, "userStatusContextMenu")
        }

        function test_menuIsNotBuiltBeforeTheFirstClick() {
            const button = createTemporaryObject(buttonComponent, root)
            verify(!menuOf(button))
        }

        function test_clickBuildsAndOpensTheMenu() {
            const button = createTemporaryObject(buttonComponent, root)
            mouseClick(button)

            const menu = menuOf(button)
            verify(!!menu)
            tryCompare(menu, "opened", true)
            compare(menu.name, "Alice")
        }

        function test_closeDestroysTheMenu() {
            const button = createTemporaryObject(buttonComponent, root)
            mouseClick(button)
            menu = menuOf(button)
            tryCompare(menu, "opened", true)

            mouseClick(button)
            tryVerify(() => menu === null)
            verify(!menuOf(button))
        }

        function test_menuRequestsReachTheButton() {
            const button = createTemporaryObject(buttonComponent, root)
            const spy = signalSpy.createObject(root, { target: button, signalName: "settingsRequested" })
            mouseClick(button)
            const menu = menuOf(button)
            tryCompare(menu, "opened", true)

            menu.settingsRequested()

            compare(spy.count, 1)
        }
    }
}
